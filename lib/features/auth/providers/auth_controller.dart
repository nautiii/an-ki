import 'dart:async';

import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Actions d'authentification (ViewModel des écrans de connexion et des
/// réglages) et issue de la dernière : `AsyncLoading` pendant l'opération,
/// `AsyncError` portant un [AuthFailure] si elle échoue, sinon `AsyncData`.
///
/// Opérations attendues (réseau, plugins) : un appel pendant une autre est
/// ignoré. Chaque méthode renvoie `true` si l'opération a abouti, pour la
/// réaction immédiate de l'écran (vibration, message) ; un écran annonce
/// l'échec en écoutant ce provider. Une annulation par l'utilisateur
/// (sélecteur Google, invite d'empreinte) n'est pas un échec.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  BiometricService get _biometrics => ref.read(biometricServiceProvider);

  BiometricLockNotifier get _lock => ref.read(biometricLockProvider.notifier);

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String surname,
  }) {
    final repository = _repository;
    return _signIn(
      AuthFailure.signUpFailed,
      () => repository.signUp(
        email: email,
        password: password,
        displayName: '$name $surname',
      ),
    );
  }

  Future<bool> signIn({required String email, required String password}) {
    final repository = _repository;
    return _signIn(
      AuthFailure.signInFailed,
      () => repository.signInWithEmail(email: email, password: password),
    );
  }

  Future<bool> signInWithGoogle() {
    final repository = _repository;
    return _signIn(AuthFailure.googleSignInFailed, repository.signInWithGoogle);
  }

  Future<bool> signInAnonymously() {
    final repository = _repository;
    return _signIn(AuthFailure.signInFailed, repository.signInAnonymously);
  }

  /// Lie le compte anonyme courant à un compte Google : ses données restent.
  Future<bool> linkWithGoogle() {
    final repository = _repository;
    return _run(AuthFailure.googleSignInFailed, () async {
      await repository.linkCurrentUserWithGoogle();
      return true;
    });
  }

  /// Ouvre l'app par l'empreinte : le jeton de l'appareil doit correspondre
  /// à celui du profil. Sans jeton, ou avec un jeton périmé, la connexion par
  /// empreinte est retirée.
  Future<bool> unlockWithBiometrics() {
    final biometrics = _biometrics;
    final repository = _repository;
    final lock = _lock;
    return _run(AuthFailure.biometricFailed, () async {
      if (!await biometrics.authenticate()) return false;
      final token = await biometrics.getStoredToken();
      final uid = await biometrics.getStoredUserId();
      if (token == null || uid == null) {
        lock.disable();
        return false;
      }
      if (!await repository.isBiometricTokenValid(uid, token)) {
        // Jeton expiré ou invalide en base.
        await biometrics.clearBiometricData();
        lock.disable();
        return false;
      }
      lock.unlock(uid: uid);
      return true;
    });
  }

  /// Active la connexion par empreinte pour le compte connecté : un jeton
  /// enregistré sur le profil et dans le stockage sécurisé de l'appareil.
  Future<bool> enableBiometrics() {
    final biometrics = _biometrics;
    final repository = _repository;
    final lock = _lock;
    return _run(AuthFailure.biometricFailed, () async {
      final user = repository.currentUser;
      if (user == null || !await biometrics.canUseFingerprint()) return false;
      final token = biometrics.generateToken();
      await repository.setBiometricToken(user.uid, token);
      await biometrics.saveBiometricData(user.uid, token);
      lock.enable();
      return true;
    });
  }

  /// Retire la connexion par empreinte : jeton effacé du profil et de
  /// l'appareil.
  Future<bool> disableBiometrics() {
    final biometrics = _biometrics;
    final repository = _repository;
    final lock = _lock;
    return _run(AuthFailure.biometricFailed, () async {
      await _clearBiometrics(repository, biometrics);
      lock.disable();
      return true;
    });
  }

  /// Déconnexion. Avec la connexion par empreinte, l'app se verrouille
  /// seulement : la session Firebase reste, pour garder les droits Firestore
  /// jusqu'au déverrouillage.
  Future<bool> signOut() {
    final biometrics = _biometrics;
    final repository = _repository;
    final lock = _lock;
    return _run(AuthFailure.signOutFailed, () async {
      if (await biometrics.getStoredToken() != null) {
        // Force le choix du compte à la prochaine connexion Google.
        await repository.signOutGoogle();
        lock.lock();
      } else {
        await repository.signOutFirebase();
        await repository.signOutGoogle();
        lock.disable();
      }
      return true;
    });
  }

  /// Supprime le compte d'authentification, une fois ses données effacées
  /// par les réglages, puis la connexion Google et l'empreinte.
  Future<bool> deleteAccount() {
    final biometrics = _biometrics;
    final repository = _repository;
    final lock = _lock;
    return _run(AuthFailure.deleteAccountFailed, () async {
      await repository.deleteCurrentUser();
      // Firebase ferme déjà la session d'un compte supprimé : on le dit.
      await repository.signOutFirebase();
      await repository.signOutGoogle();
      // Le profil, jeton compris, est déjà effacé, et la session fermée
      // interdit d'y écrire : seul l'appareil garde un jeton à oublier.
      await biometrics.clearBiometricData();
      lock.disable();
      return true;
    });
  }

  /// Connexion explicite : elle passe aussi le verrou biométrique.
  Future<bool> _signIn(AuthFailure fallback, Future<Object?> Function() call) {
    final lock = _lock;
    return _run(fallback, () async {
      await call();
      lock.unlock();
      return true;
    });
  }

  /// Exécute [operation] et publie son issue ; renvoie son résultat, `false`
  /// pour un appel ignoré, une annulation ou un échec. Une erreur inattendue
  /// devient [fallback].
  Future<bool> _run(
    AuthFailure fallback,
    Future<bool> Function() operation,
  ) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      final done = await operation();
      if (ref.mounted) state = const AsyncData(null);
      return done;
    } on GoogleSignInException catch (error, stackTrace) {
      // Le sélecteur de compte fermé par l'utilisateur n'est pas un échec.
      if (ref.mounted) {
        state = error.code == GoogleSignInExceptionCode.canceled
            ? const AsyncData(null)
            : AsyncError(AuthFailure.googleSignInFailed, stackTrace);
      }
      return false;
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncError(error is AuthFailure ? error : fallback, stackTrace);
      }
      return false;
    }
  }
}

/// Efface le jeton d'empreinte du profil (compte connecté, sinon celui du
/// jeton) puis de l'appareil.
Future<void> _clearBiometrics(
  AuthRepository repository,
  BiometricService biometrics,
) async {
  final uid = repository.currentUser?.uid ?? await biometrics.getStoredUserId();
  if (uid != null) await repository.setBiometricToken(uid, null);
  await biometrics.clearBiometricData();
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
