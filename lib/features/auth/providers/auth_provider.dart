import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.canUseBiometrics = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? errorMessage,
    bool? canUseBiometrics,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      canUseBiometrics: canUseBiometrics ?? this.canUseBiometrics,
    );
  }

  bool get isAuthenticated => user != null;

  bool get isAnonymous => user?.isAnonymous ?? false;
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
  BiometricService get _biometricService => BiometricService.instance;

  void initializeAuth() {
    _firebaseAuth.authStateChanges().listen((User? user) {
      if (ref.mounted) {
        state = state.copyWith(user: user);
      }
    });
  }

  Future<void> _checkBiometricAvailability() async {
    final canUse = await _biometricService.canAuthenticate();
    final isEnabled = await _biometricService.isBiometricEnabled();
    state = state.copyWith(canUseBiometrics: canUse && isEnabled);
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String surname,
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
        errorMessage: _getErrorMessage(e.code),
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (await _biometricService.isBiometricEnabled()) {
        await _biometricService.saveCredentials(email, password);
      }

      state = state.copyWith(user: userCredential.user, isLoading: false);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code),
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> signInWithBiometrics(BuildContext context) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final isAuthenticated = await _biometricService.authenticate(context.l10n.biometricReason);
      if (!isAuthenticated) {
        state = state.copyWith(isLoading: false, errorMessage: "");
        return false;
      }

      final authMethod = await _biometricService.getAuthMethod();

      if (authMethod == 'google') {
        return await signInWithGoogle(isBiometricTriggered: true);
      } else {
        final credentials = await _biometricService.getCredentials();
        if (credentials == null) {
          state = state.copyWith(
            errorMessage: context.l10n.noBiometricCredentials,
            isLoading: false,
          );
          return false;
        }

        final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: credentials['email']!,
          password: credentials['password']!,
        );

        state = state.copyWith(user: userCredential.user, isLoading: false);
        return true;
      }
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code),
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: context.l10n.biometricError,
        isLoading: false,
      );
      return false;
    }
  }

  Future<void> enableBiometrics(String email, String password) async {
    final canUse = await _biometricService.canAuthenticate();
    if (canUse) {
      await _biometricService.setBiometricEnabled(true);
      if (email.isNotEmpty && password.isNotEmpty) {
        await _biometricService.saveCredentials(email, password);
      } else if (_firebaseAuth.currentUser != null) {
        // Détecter si c'est un utilisateur Google
        final user = _firebaseAuth.currentUser!;
        final isGoogle = user.providerData.any(
          (p) => p.providerId == 'google.com',
        );
        if (isGoogle) {
          await _biometricService.saveGoogleAuthMarker();
        }
      }
      state = state.copyWith(canUseBiometrics: true);
    }
  }

  Future<void> disableBiometrics() async {
    await _biometricService.setBiometricEnabled(false);
    await _biometricService.clearCredentials();
    state = state.copyWith(canUseBiometrics: false);
  }

  Future<void> signOut() async {
    try {
      state = state.copyWith(isLoading: true);
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
      state = AuthState(canUseBiometrics: state.canUseBiometrics);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Erreur lors de la déconnexion',
        isLoading: false,
      );
    }
  }

  Future<void> deleteAccount() async {
    try {
      state = state.copyWith(isLoading: true);
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.delete();
      }
      await _googleSignIn.signOut();
      await _biometricService.clearCredentials();
      state = AuthState();
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code),
        isLoading: false,
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Erreur lors de la suppression du compte',
        isLoading: false,
      );
      rethrow;
    }
  }

  Future<bool> signInAnonymously() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final userCredential = await _firebaseAuth.signInAnonymously();
      state = state.copyWith(user: userCredential.user, isLoading: false);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code),
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle({bool isBiometricTriggered = false}) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      // Si c'est déclenché par la biométrie, on tente d'abord un silent sign-in
      GoogleSignInAccount? googleUser;
      if (isBiometricTriggered) {
        googleUser = await _googleSignIn.attemptLightweightAuthentication();
      }

      // Si pas de silent sign-in possible ou pas biométrique, on fait le workflow normal
      googleUser ??= await _googleSignIn.authenticate(scopeHint: ['email']);

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
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

      if (await _biometricService.isBiometricEnabled()) {
        await _biometricService.saveGoogleAuthMarker();
      }

      state = state.copyWith(user: userCredential.user, isLoading: false);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        errorMessage: _getErrorMessage(e.code),
        isLoading: false,
      );
      return false;
    } on GoogleSignInException catch (e) {
      state = state.copyWith(
        errorMessage:
            e.code == GoogleSignInExceptionCode.canceled
                ? null
                : 'Erreur lors de la connexion Google',
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Erreur lors de la connexion Google',
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> linkWithGoogle() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
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
        errorMessage: _getErrorMessage(e.code),
        isLoading: false,
      );
      return false;
    } on GoogleSignInException catch (e) {
      state = state.copyWith(
        errorMessage:
            e.code == GoogleSignInExceptionCode.canceled
                ? null
                : 'Erreur lors de la connexion Google',
        isLoading: false,
      );
      return false;
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Le mot de passe est trop faible.';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé.';
      case 'invalid-email':
        return 'L\'email n\'est pas valide.';
      case 'user-not-found':
        return 'Utilisateur non trouvé.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      default:
        return 'Une erreur est survenue.';
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
