import 'dart:async';

import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/domain/guest_linked.dart';
import 'package:an_ki/features/auth/domain/sign_in_method.dart';
import 'package:an_ki/features/auth/providers/fresh_sign_in_provider.dart';
import 'package:an_ki/features/auth/providers/guest_links.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
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
  /// rien ne change. Chaque essai propose tous les comptes : le dernier
  /// choisi est oublié avant, et après un refus, sauf un compte déjà connu
  /// d'AnKi, que [openGoogleAccount] reprend sans sélecteur.
  Future<bool> linkWithGoogle() {
    final repository = _repository;
    final guestLinks = ref.read(guestLinksProvider.notifier);
    return _run(AuthFailure.googleSignInFailed, () async {
      await _forgetGoogleAccount(repository);
      try {
        await repository.linkCurrentUserWithGoogle();
      } on AuthFailure catch (failure) {
        if (failure != AuthFailure.credentialAlreadyInUse) {
          await _forgetGoogleAccount(repository);
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

  /// Ouvre le compte Google déjà connu d'AnKi que la liaison vient de refuser
  /// ([AuthFailure.credentialAlreadyInUse]), comme une connexion : la session
  /// d'invité est remplacée. [prepare] reçoit son adresse pendant qu'elle est
  /// encore ouverte ; s'il renvoie false, rien ne s'ouvre et l'issue reste
  /// `AsyncData` : l'appelant publie son propre échec.
  Future<bool> openGoogleAccount(Future<bool> Function(String email) prepare) {
    final repository = _repository;
    return _signIn(
      AuthFailure.googleSignInFailed,
      () => repository.signInWithGoogleAccount(prepare),
    );
  }

  /// Oublie le compte Google choisi, au mieux : l'issue à annoncer reste celle
  /// de l'opération en cours.
  Future<void> _forgetGoogleAccount(AuthRepository repository) async {
    try {
      await repository.signOutGoogle();
    } on Exception {
      // Rien à faire : le sélecteur reprendra peut-être ce compte.
    }
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

  /// Confirme l'identité du compte connecté avant sa suppression, que
  /// Firebase refuse à une connexion trop ancienne : Google rouvre son
  /// sélecteur, un compte e-mail donne [password]. Un invité n'a rien pour la
  /// confirmer : il passe. Le sélecteur fermé est une annulation.
  Future<bool> confirmIdentity({String? password}) {
    final repository = _repository;
    final method = ref.read(signInMethodProvider);
    return _run(AuthFailure.deleteAccountFailed, () async {
      switch (method) {
        case null:
          return false;
        case SignInMethod.guest:
          break;
        case SignInMethod.google:
          try {
            await repository.reauthenticateWithGoogle();
          } on AuthFailure {
            // Le compte Google choisi est oublié : un nouvel essai les
            // propose tous, au lieu de reprendre le mauvais.
            try {
              await repository.signOutGoogle();
            } on Exception {
              // Oubli au mieux : l'échec à annoncer reste la confirmation.
            }
            rethrow;
          }
        case SignInMethod.email:
          await repository.reauthenticateWithPassword(password ?? '');
      }
      return true;
    });
  }

  /// Supprime le compte d'authentification, une fois ses données effacées
  /// par les réglages, puis la connexion Google et l'empreinte. Le compte
  /// supprimé, l'opération a abouti : le nettoyage qui suit se fait au mieux,
  /// son échec n'annonce pas une suppression ratée. Renvoie `true` seulement
  /// une fois la session fermée.
  Future<bool> deleteAccount() {
    final biometrics = _biometrics;
    final repository = _repository;
    final lock = _lock;
    return _run(AuthFailure.deleteAccountFailed, () async {
      final guest = repository.currentUser?.isAnonymous ?? false;
      try {
        await repository.deleteCurrentUser();
      } on AuthFailure catch (failure) {
        // Un invité ne peut pas confirmer son identité : vidé de ses données,
        // son compte devient injoignable une fois la session fermée.
        if (!guest || failure != AuthFailure.requiresRecentLogin) rethrow;
      }
      // Firebase ferme déjà la session d'un compte supprimé : on le dit.
      await _bestEffort(repository.signOutFirebase);
      await _bestEffort(repository.signOutGoogle);
      // Le profil, jeton compris, est déjà effacé, et la session fermée
      // interdit d'y écrire : seul l'appareil garde un jeton à oublier.
      await _bestEffort(biometrics.clearBiometricData);
      // Réussie veut dire session fermée : le dialogue attend la redirection.
      // Un invité refusé par Firebase n'est injoignable qu'une fois sorti.
      if (repository.currentUser != null) throw AuthFailure.deleteAccountFailed;
      lock.disable();
      return true;
    });
  }

  /// Exécute [cleanup] au mieux : l'issue à annoncer reste celle de
  /// l'opération en cours.
  Future<void> _bestEffort(Future<void> Function() cleanup) async {
    try {
      await cleanup();
    } on Exception {
      // Rien à faire : l'étape suivante a lieu quand même.
    }
  }

  /// Connexion explicite : elle passe aussi le verrou biométrique et se note
  /// ([freshSignInProvider]). L'empreinte d'un autre compte est oubliée : sa
  /// session vient d'être remplacée. [call] sans utilisateur : rien ne s'est
  /// ouvert, rien ne change.
  Future<bool> _signIn(AuthFailure fallback, Future<User?> Function() call) {
    final biometrics = _biometrics;
    final repository = _repository;
    final lock = _lock;
    final freshSignIn = ref.read(freshSignInProvider.notifier);
    return _run(fallback, () async {
      if (await call() == null) return false;
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
