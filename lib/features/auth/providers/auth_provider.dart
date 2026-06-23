import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/repositories/auth_repository.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
    // Si la biométrie est configurée, on exige la validation biométrique.
    if (canUseBiometrics) {
      return isBiometricallyAuthenticated;
    }
    // Sinon une simple session Firebase suffit.
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

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  BiometricService get _biometricService => BiometricService.instance;

  void initializeAuth() {
    _repository.authStateChanges().listen((User? user) {
      if (ref.mounted) {
        state = state.copyWith(
          user: user,
          // Une connexion Google/Email valide automatiquement la biométrie.
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
      // Si un utilisateur Firebase est déjà présent au démarrage, la biométrie
      // doit quand même être validée lorsqu'elle est configurée.
      isBiometricallyAuthenticated:
          (canUse && hasToken) ? false : _repository.currentUser != null,
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
      state = state.copyWith(isLoading: true);

      final user = await _repository.signUp(
        email: email,
        password: password,
        displayName: "$name $surname",
      );

      state = state.copyWith(user: user, isLoading: false);
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
      state = state.copyWith(isLoading: true);

      final user = await _repository.signInWithEmail(
        email: email,
        password: password,
      );

      state = state.copyWith(
        user: user,
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
      state = state.copyWith(isLoading: true);

      final user = await _repository.signInWithGoogle();

      state = state.copyWith(
        user: user,
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
      state = state.copyWith(isLoading: true);

      // 1. Authentification physique.
      final authenticated = await _biometricService.authenticate();
      if (!authenticated) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      // 2. Récupération des tokens locaux.
      final token = await _biometricService.getStoredToken();
      final uid = await _biometricService.getStoredUserId();

      if (token == null || uid == null) {
        state = state.copyWith(isLoading: false, canUseBiometrics: false);
        return false;
      }

      // 3. Vérification côté Firestore.
      final isValid = await _repository.isBiometricTokenValid(uid, token);
      if (!isValid) {
        // Token expiré ou invalide en base.
        await _biometricService.clearBiometricData();
        state = state.copyWith(isLoading: false, canUseBiometrics: false);
        return false;
      }

      // 4. Succès local — on met à jour l'état pour déclencher la navigation/init.
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
    final user = _repository.currentUser;
    if (user == null) return;

    final canUse = await _biometricService.canUseFingerprint();
    if (!canUse) return;

    // 1. Génération du token.
    final token = _biometricService.generateToken();

    // 2. Persistance en base.
    await _repository.setBiometricToken(user.uid, token);

    // 3. Persistance dans le stockage sécurisé.
    await _biometricService.saveBiometricData(user.uid, token);

    state = state.copyWith(
      canUseBiometrics: true,
      isBiometricallyAuthenticated: true,
    );
  }

  Future<void> disableBiometrics() async {
    final uid =
        _repository.currentUser?.uid ??
        await _biometricService.getStoredUserId();

    if (uid != null) {
      await _repository.setBiometricToken(uid, null);
    }

    await _biometricService.clearBiometricData();
    state = state.copyWith(canUseBiometrics: false);
  }

  Future<void> signOut(AppLocalizations l10n) async {
    try {
      state = state.copyWith(isLoading: true);

      final hasToken = await _biometricService.getStoredToken() != null;

      if (hasToken) {
        // VERROUILLAGE LOCAL UNIQUEMENT.
        // On garde la session Firebase pour préserver les droits Firestore.
        // (Optionnel : force le choix du compte si on repasse par Google.)
        await _repository.signOutGoogle();

        state = state.copyWith(
          isLoading: false,
          isBiometricallyAuthenticated: false,
        );
      } else {
        // DÉCONNEXION COMPLÈTE.
        await _repository.signOutFirebase();
        await _repository.signOutGoogle();
        state = AuthState();
      }
    } catch (e) {
      state = state.copyWith(errorMessage: l10n.errorSignOut, isLoading: false);
    }
  }

  Future<bool> signInAnonymously(AppLocalizations l10n) async {
    try {
      state = state.copyWith(isLoading: true);
      final user = await _repository.signInAnonymously();
      state = state.copyWith(
        user: user,
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
      state = state.copyWith(isLoading: true);
      final user = await _repository.linkCurrentUserWithGoogle();
      state = state.copyWith(user: user, isLoading: false);
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
      await _repository.deleteCurrentUser();
      await _repository.signOutGoogle();
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
