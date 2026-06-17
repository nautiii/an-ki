import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/user/data/repositories/user_repository.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);
final googleSignInProvider = Provider<GoogleSignIn>(
  (ref) => GoogleSignIn.instance,
);

class AuthState {
  final User? user;
  final bool isLoading;
  final String? errorMessage;
  final bool canUseBiometrics;
  final bool isBiometricallyAuthenticated;
  final String? biometricUid;

  AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.canUseBiometrics = false,
    this.isBiometricallyAuthenticated = false,
    this.biometricUid,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? errorMessage,
    bool? canUseBiometrics,
    bool? isBiometricallyAuthenticated,
    String? biometricUid,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      canUseBiometrics: canUseBiometrics ?? this.canUseBiometrics,
      isBiometricallyAuthenticated:
          isBiometricallyAuthenticated ?? this.isBiometricallyAuthenticated,
      biometricUid: biometricUid ?? this.biometricUid,
    );
  }

  bool get isAuthenticated {
    // Si la biométrie est configurée, on exige la validation biométrique
    if (canUseBiometrics) {
      return isBiometricallyAuthenticated;
    }
    // Sinon simple vérification de session Firebase
    return user != null;
  }

  bool get isAnonymous => user?.isAnonymous ?? false;

  String? get uid => user?.uid ?? biometricUid;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    initializeAuth();
    _checkBiometricAvailability();
    return AuthState();
  }

  FirebaseAuth get _firebaseAuth => ref.watch(firebaseAuthProvider);

  GoogleSignIn get _googleSignIn => ref.watch(googleSignInProvider);

  UserRepository get _userRepository => ref.watch(userRepositoryProvider);

  BiometricService get _biometricService => BiometricService.instance;

  void initializeAuth() {
    _firebaseAuth.authStateChanges().listen((User? user) {
      if (ref.mounted) {
        state = state.copyWith(
          user: user,
          // Si on se connecte via Google/Email, on valide automatiquement la biométrie
          isBiometricallyAuthenticated:
              user != null ? true : state.isBiometricallyAuthenticated,
        );
      }
    });
  }

  Future<void> _checkBiometricAvailability() async {
    final canUse = await _biometricService.canUseFingerprint();
    final hasToken = await _biometricService.getStoredToken() != null;

    if (!ref.mounted) return;

    state = state.copyWith(
      canUseBiometrics: canUse && hasToken,
      // Si on a déjà un utilisateur Firebase au démarrage, on considère
      // qu'on doit quand même valider la biométrie si elle est configurée.
      isBiometricallyAuthenticated:
          (canUse && hasToken) ? false : _firebaseAuth.currentUser != null,
    );
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String surname,
    required AppLocalizations l10n,
  }) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName("$name $surname");
        await user.reload();
      }

      state = state.copyWith(user: _firebaseAuth.currentUser, isLoading: false);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code, l10n),
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: l10n.registrationError,
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
    required AppLocalizations l10n,
  }) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      state = state.copyWith(
        user: userCredential.user,
        isLoading: false,
        isBiometricallyAuthenticated: true,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code, l10n),
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: l10n.connectionError,
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle(AppLocalizations l10n) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email'],
      );

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final GoogleSignInClientAuthorization authorization = await googleUser
          .authorizationClient
          .authorizeScopes(['email']);

      final credential = GoogleAuthProvider.credential(
        accessToken: authorization.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      state = state.copyWith(
        user: userCredential.user,
        isLoading: false,
        isBiometricallyAuthenticated: true,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code, l10n),
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: l10n.errorGoogleLogin,
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> signInWithBiometricToken(AppLocalizations l10n) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      // 1. Authentification physique
      final authenticated = await _biometricService.authenticate();
      if (!authenticated) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      // 2. Récupération des tokens locaux
      final token = await _biometricService.getStoredToken();
      final uid = await _biometricService.getStoredUserId();

      if (token == null || uid == null) {
        state = state.copyWith(isLoading: false, canUseBiometrics: false);
        return false;
      }

      // 3. Vérification Firestore
      final user = await _userRepository.fetchUserByToken(uid, token);
      if (user == null) {
        // Token expiré ou invalide en base
        await _biometricService.clearBiometricData();
        state = state.copyWith(isLoading: false, canUseBiometrics: false);
        return false;
      }

      // 4. Succès local - On met à jour l'état pour déclencher la navigation/initialisation
      state = state.copyWith(
        isLoading: false,
        isBiometricallyAuthenticated: true,
        biometricUid: uid,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: l10n.biometricError,
        isLoading: false,
      );
      return false;
    }
  }

  Future<void> enableBiometrics() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final canUse = await _biometricService.canUseFingerprint();
    if (!canUse) return;

    // 1. Générer le token
    final token = _biometricService.generateToken();

    // 2. Sauvegarder en base
    await _userRepository.updateBiometricToken(user.uid, token);

    // 3. Sauvegarder en cache sécurisé
    await _biometricService.saveBiometricData(user.uid, token);

    state = state.copyWith(
      canUseBiometrics: true,
      isBiometricallyAuthenticated: true,
    );
  }

  Future<void> disableBiometrics() async {
    final uid =
        _firebaseAuth.currentUser?.uid ??
        await _biometricService.getStoredUserId();

    if (uid != null) {
      await _userRepository.updateBiometricToken(uid, null);
    }

    await _biometricService.clearBiometricData();
    state = state.copyWith(canUseBiometrics: false);
  }

  Future<void> signOut(AppLocalizations l10n) async {
    try {
      state = state.copyWith(isLoading: true);

      final hasToken = await _biometricService.getStoredToken() != null;

      if (hasToken) {
        // LOCK LOCAL UNIQUEMENT
        // On ne déconnecte pas Firebase pour garder les droits Firestore
        await _googleSignIn
            .signOut(); // Optionnel, pour forcer le choix de compte si on repasse par Google

        state = state.copyWith(
          isLoading: false,
          isBiometricallyAuthenticated: false,
        );
      } else {
        // DÉCONNEXION TOTALE
        await _firebaseAuth.signOut();
        await _googleSignIn.signOut();
        state = AuthState();
      }
    } catch (e) {
      state = state.copyWith(errorMessage: l10n.errorSignOut, isLoading: false);
    }
  }

  Future<bool> signInAnonymously(AppLocalizations l10n) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final userCredential = await _firebaseAuth.signInAnonymously();
      state = state.copyWith(
        user: userCredential.user,
        isLoading: false,
        isBiometricallyAuthenticated: true,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code, l10n),
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> linkWithGoogle(AppLocalizations l10n) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final GoogleSignInClientAuthorization authorization = await googleUser
          .authorizationClient
          .authorizeScopes(['email']);

      final credential = GoogleAuthProvider.credential(
        accessToken: authorization.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await state.user?.linkWithCredential(credential);
      state = state.copyWith(user: userCredential?.user, isLoading: false);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code, l10n),
        isLoading: false,
      );
      return false;
    } on GoogleSignInException catch (e) {
      state = state.copyWith(
        errorMessage:
            e.code == GoogleSignInExceptionCode.canceled
                ? null
                : l10n.errorGoogleLogin,
        isLoading: false,
      );
      return false;
    }
  }

  Future<void> deleteAccount(AppLocalizations l10n) async {
    try {
      state = state.copyWith(isLoading: true);
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.delete();
      }
      await _googleSignIn.signOut();
      await disableBiometrics();
      state = AuthState();
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code, l10n),
        isLoading: false,
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        errorMessage: l10n.deleteAccountError,
        isLoading: false,
      );
      rethrow;
    }
  }

  String _getErrorMessage(String code, AppLocalizations l10n) {
    switch (code) {
      case 'weak-password':
        return l10n.errorWeakPassword;
      case 'email-already-in-use':
        return l10n.errorEmailAlreadyInUse;
      case 'invalid-email':
        return l10n.errorInvalidEmail;
      case 'user-not-found':
        return l10n.errorUserNotFound;
      case 'wrong-password':
        return l10n.errorWrongPassword;
      default:
        return l10n.errorUnknown;
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
