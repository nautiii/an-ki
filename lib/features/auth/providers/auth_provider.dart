import 'dart:async';

import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Session et verrou biométrique, plus l'issue de la dernière opération.
///
/// [failure] décrit l'échec de la dernière opération (null sinon) : l'UI en
/// tire le message, l'état ne porte aucun texte.
class AuthState {
  final User? user;
  final bool isLoading;
  final AuthFailure? failure;
  final bool canUseBiometrics;
  final bool isBiometricallyAuthenticated;
  final String? biometricUid;

  AuthState({
    this.user,
    this.isLoading = false,
    this.failure,
    this.canUseBiometrics = false,
    this.isBiometricallyAuthenticated = false,
    this.biometricUid,
  });

  /// Copie modifiée. Un argument null signifie « inchangé » ; `clearFailure`
  /// efface l'échec précédent.
  AuthState copyWith({
    User? user,
    bool? isLoading,
    AuthFailure? failure,
    bool clearFailure = false,
    bool? canUseBiometrics,
    bool? isBiometricallyAuthenticated,
    String? biometricUid,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
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

  @override
  bool operator ==(Object other) =>
      other is AuthState &&
      other.user == user &&
      other.isLoading == isLoading &&
      other.failure == failure &&
      other.canUseBiometrics == canUseBiometrics &&
      other.isBiometricallyAuthenticated == isBiometricallyAuthenticated &&
      other.biometricUid == biometricUid;

  @override
  int get hashCode => Object.hash(
    user,
    isLoading,
    failure,
    canUseBiometrics,
    isBiometricallyAuthenticated,
    biometricUid,
  );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    ref.onDispose(() => _authSubscription?.cancel());
    initializeAuth();
    _checkBiometricAvailability();
    return AuthState();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  BiometricService get _biometricService => ref.read(biometricServiceProvider);

  StreamSubscription<User?>? _authSubscription;

  void initializeAuth() {
    unawaited(_authSubscription?.cancel());
    _authSubscription = _repository.authStateChanges().listen((User? user) {
      if (ref.mounted) {
        state = state.copyWith(
          user: user,
          // Une connexion Google/Email valide automatiquement la biométrie.
          isBiometricallyAuthenticated: user != null
              ? true
              : state.isBiometricallyAuthenticated,
        );
      }
    });
  }

  Future<void> _checkBiometricAvailability() async {
    // Dépendance lue avant le premier await : le notifier peut être libéré
    // pendant l'attente, et ref ne s'utilise plus après.
    final biometrics = _biometricService;
    final canUse = await biometrics.canUseFingerprint();
    final hasToken = await biometrics.getStoredToken() != null;

    if (!ref.mounted) return;

    state = state.copyWith(
      canUseBiometrics: canUse && hasToken,
      // Si un utilisateur Firebase est déjà présent au démarrage, la biométrie
      // doit quand même être validée lorsqu'elle est configurée.
      isBiometricallyAuthenticated: (canUse && hasToken)
          ? false
          : _repository.currentUser != null,
    );
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String surname,
  }) async {
    try {
      state = state.copyWith(isLoading: true, clearFailure: true);

      final user = await _repository.signUp(
        email: email,
        password: password,
        displayName: "$name $surname",
      );

      state = state.copyWith(user: user, isLoading: false);
      return true;
    } on AuthFailure catch (failure) {
      state = state.copyWith(failure: failure, isLoading: false);
      return false;
    } catch (_) {
      state = state.copyWith(
        failure: AuthFailure.signUpFailed,
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    try {
      state = state.copyWith(isLoading: true, clearFailure: true);

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
    } on AuthFailure catch (failure) {
      state = state.copyWith(failure: failure, isLoading: false);
      return false;
    } catch (_) {
      state = state.copyWith(
        failure: AuthFailure.signInFailed,
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      state = state.copyWith(isLoading: true, clearFailure: true);

      final user = await _repository.signInWithGoogle();

      state = state.copyWith(
        user: user,
        isLoading: false,
        isBiometricallyAuthenticated: true,
      );
      return true;
    } on AuthFailure catch (failure) {
      state = state.copyWith(failure: failure, isLoading: false);
      return false;
    } on GoogleSignInException catch (e) {
      // Une annulation par l'utilisateur n'est pas un échec à signaler.
      state = state.copyWith(
        failure: e.code == GoogleSignInExceptionCode.canceled
            ? null
            : AuthFailure.googleSignInFailed,
        isLoading: false,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        failure: AuthFailure.googleSignInFailed,
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> signInWithBiometricToken() async {
    try {
      state = state.copyWith(isLoading: true, clearFailure: true);
      final biometrics = _biometricService;

      // 1. Authentification physique.
      final authenticated = await biometrics.authenticate();
      if (!authenticated) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      // 2. Récupération des tokens locaux.
      final token = await biometrics.getStoredToken();
      final uid = await biometrics.getStoredUserId();

      if (token == null || uid == null) {
        state = state.copyWith(isLoading: false, canUseBiometrics: false);
        return false;
      }

      // 3. Vérification côté Firestore.
      final isValid = await _repository.isBiometricTokenValid(uid, token);
      if (!isValid) {
        // Token expiré ou invalide en base.
        await biometrics.clearBiometricData();
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
    } catch (_) {
      state = state.copyWith(
        failure: AuthFailure.biometricFailed,
        isLoading: false,
      );
      return false;
    }
  }

  Future<void> enableBiometrics() async {
    final user = _repository.currentUser;
    if (user == null) return;
    final biometrics = _biometricService;

    final canUse = await biometrics.canUseFingerprint();
    if (!canUse) return;

    // 1. Génération du token.
    final token = biometrics.generateToken();

    // 2. Persistance en base.
    await _repository.setBiometricToken(user.uid, token);

    // 3. Persistance dans le stockage sécurisé.
    await biometrics.saveBiometricData(user.uid, token);

    state = state.copyWith(
      canUseBiometrics: true,
      isBiometricallyAuthenticated: true,
    );
  }

  Future<void> disableBiometrics() async {
    final biometrics = _biometricService;
    final uid =
        _repository.currentUser?.uid ?? await biometrics.getStoredUserId();

    if (uid != null) {
      await _repository.setBiometricToken(uid, null);
    }

    await biometrics.clearBiometricData();
    state = state.copyWith(canUseBiometrics: false);
  }

  Future<void> signOut() async {
    try {
      state = state.copyWith(isLoading: true, clearFailure: true);

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
    } catch (_) {
      state = state.copyWith(
        failure: AuthFailure.signOutFailed,
        isLoading: false,
      );
    }
  }

  Future<bool> signInAnonymously() async {
    try {
      state = state.copyWith(isLoading: true, clearFailure: true);
      final user = await _repository.signInAnonymously();
      state = state.copyWith(
        user: user,
        isLoading: false,
        isBiometricallyAuthenticated: true,
      );
      return true;
    } on AuthFailure catch (failure) {
      state = state.copyWith(failure: failure, isLoading: false);
      return false;
    }
  }

  Future<bool> linkWithGoogle() async {
    try {
      state = state.copyWith(isLoading: true, clearFailure: true);
      final user = await _repository.linkCurrentUserWithGoogle();
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } on AuthFailure catch (failure) {
      state = state.copyWith(failure: failure, isLoading: false);
      return false;
    } on GoogleSignInException catch (e) {
      // Une annulation par l'utilisateur n'est pas un échec à signaler.
      state = state.copyWith(
        failure: e.code == GoogleSignInExceptionCode.canceled
            ? null
            : AuthFailure.googleSignInFailed,
        isLoading: false,
      );
      return false;
    }
  }

  Future<void> deleteAccount() async {
    try {
      state = state.copyWith(isLoading: true, clearFailure: true);
      await _repository.deleteCurrentUser();
      await _repository.signOutGoogle();
      await disableBiometrics();
      state = AuthState();
    } on AuthFailure catch (failure) {
      state = state.copyWith(failure: failure, isLoading: false);
      rethrow;
    } catch (_) {
      state = state.copyWith(
        failure: AuthFailure.deleteAccountFailed,
        isLoading: false,
      );
      rethrow;
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
