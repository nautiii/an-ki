import 'dart:async';

import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/domain/guest_linked.dart';
import 'package:an_ki/features/auth/providers/fresh_sign_in_provider.dart';
import 'package:an_ki/features/auth/providers/guest_links.dart';
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
///
/// L'empreinte ne vaut que pour le compte qui l'a activée : elle déverrouille
/// sa session Firebase, jamais une autre, et ne remplace pas une connexion.
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

  /// Lie le compte anonyme courant à un compte Google : ses données restent,
  /// et la liaison se note ([guestLinksProvider]) pour que le profil prenne
  /// les noms du compte Google. Refusée (compte Google déjà pris, réseau…),
  /// rien ne change ; le compte Google choisi est oublié, pour qu'un nouvel
  /// essai propose de nouveau tous les comptes.
  Future<bool> linkWithGoogle() {
    final repository = _repository;
    final guestLinks = ref.read(guestLinksProvider.notifier);
    return _run(AuthFailure.googleSignInFailed, () async {
      try {
        await repository.linkCurrentUserWithGoogle();
      } on AuthFailure {
        try {
          await repository.signOutGoogle();
        } on Exception {
          // Oubli au mieux : l'échec à annoncer reste celui de la liaison.
        }
        rethrow;
      }
      if (repository.currentUser case final user?) {
        guestLinks.record(
          GuestLinked(uid: user.uid, displayName: user.displayName ?? ''),
        );
      }
      return true;
    });
  }

  /// Déverrouille la session Firebase par l'empreinte ; sans session, rien à
  /// ouvrir. Le jeton de l'appareil doit appartenir au compte de la session
  /// et correspondre à celui de son profil. Sinon (empreinte retirée ou
  /// réactivée sur un autre appareil, jeton d'un autre compte), la session se
  /// ferme et [AuthFailure.biometricRevoked] invite à se reconnecter.
  /// [reason] : texte de l'invite d'empreinte, choisi par l'écran.
  Future<bool> unlockWithBiometrics({required String reason}) {
    final biometrics = _biometrics;
    final repository = _repository;
    final lock = _lock;
    return _run(AuthFailure.biometricFailed, () async {
      final user = repository.currentUser;
      if (user == null || !await biometrics.authenticate(reason: reason)) {
        return false;
      }
      final token = await biometrics.getStoredToken();
      final valid =
          token != null &&
          await biometrics.getStoredUserId() == user.uid &&
          await repository.isBiometricTokenValid(user.uid, token);
      if (!valid) {
        // Session fermée d'abord : si la suite échoue, rien ne s'ouvre.
        await repository.signOutFirebase();
        await repository.signOutGoogle();
        await biometrics.clearBiometricData();
        lock.disable();
        throw AuthFailure.biometricRevoked;
      }
      lock.unlock();
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

  /// Retire la connexion par empreinte : jeton effacé du profil du compte
  /// connecté, seul à pouvoir l'écrire, puis de l'appareil.
  Future<bool> disableBiometrics() {
    final biometrics = _biometrics;
    final repository = _repository;
    final lock = _lock;
    return _run(AuthFailure.biometricFailed, () async {
      final user = repository.currentUser;
      if (user != null) await repository.setBiometricToken(user.uid, null);
      await biometrics.clearBiometricData();
      lock.disable();
      return true;
    });
  }

  /// Déconnexion. Avec la connexion par empreinte, l'app se verrouille
  /// seulement : la session Firebase reste, pour garder les droits Firestore
  /// jusqu'au déverrouillage. Sans elle (jamais activée, ou capteur devenu
  /// indisponible), la session se ferme.
  Future<bool> signOut() {
    final repository = _repository;
    final lock = _lock;
    final fingerprintOn =
        ref.read(biometricLockProvider).value?.enabled ?? false;
    return _run(AuthFailure.signOutFailed, () async {
      if (fingerprintOn) {
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

  /// Connexion explicite : elle passe aussi le verrou biométrique et se note
  /// ([freshSignInProvider]). L'empreinte d'un autre compte est oubliée : sa
  /// session vient d'être remplacée.
  Future<bool> _signIn(AuthFailure fallback, Future<Object?> Function() call) {
    final biometrics = _biometrics;
    final repository = _repository;
    final lock = _lock;
    final freshSignIn = ref.read(freshSignInProvider.notifier);
    return _run(fallback, () async {
      await call();
      if (repository.currentUser?.uid case final uid?) freshSignIn.record(uid);
      final fingerprintUid = await biometrics.getStoredUserId();
      if (fingerprintUid != null &&
          fingerprintUid != repository.currentUser?.uid) {
        await biometrics.clearBiometricData();
        lock.disable();
      } else {
        lock.unlock();
      }
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

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
