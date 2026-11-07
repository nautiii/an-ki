import 'dart:async';

import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Couche data de l'authentification.
///
/// Encapsule les SDK Firebase Auth + Google Sign-In et persiste le token
/// biométrique sur le document utilisateur. N'embarque aucune logique métier ;
/// traduit les refus de Firebase Auth en [AuthFailure] (les exceptions du
/// plugin Google remontent telles quelles). Garde la feature `auth` découplée
/// de la feature `user`.
class AuthRepository {
  AuthRepository({
    required this._auth,
    required this._googleSignIn,
    required this._firestore,
    this._signInTimeout = defaultSignInTimeout,
  });

  /// Attente maximale de Firebase à la connexion (e-mail, ou échange du
  /// jeton Google) : au-delà, [AuthFailure.signInTimeout] rend la main à
  /// l'écran, qui sinon tournerait sans fin. Le sélecteur de compte Google,
  /// qui attend l'utilisateur, n'est pas compté.
  static const defaultSignInTimeout = Duration(seconds: 30);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;
  final Duration _signInTimeout;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('user');

  /// Utilisateur de la session en temps réel : connexion, déconnexion et
  /// changements du compte (liaison d'un compte anonyme, nom affiché).
  Stream<User?> userChanges() => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  Future<User?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) => _guard(() async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      await user.updateDisplayName(displayName);
      await user.reload();
    }
    return _auth.currentUser;
  });

  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) => _guard(() async {
    final credential = await _timed(
      _auth.signInWithEmailAndPassword(email: email, password: password),
    );
    return credential.user;
  });

  /// Envoie à [email] le lien Firebase qui fait choisir un nouveau mot de
  /// passe, rédigé dans la langue [languageCode] de l'app. Avec la protection
  /// contre l'énumération des e-mails, une adresse sans compte ne dit rien :
  /// l'envoi « réussit » sans e-mail.
  Future<void> sendPasswordReset(
    String email, {
    required String languageCode,
  }) => _guard(() async {
    await _auth.setLanguageCode(languageCode);
    await _auth.sendPasswordResetEmail(email: email);
  });

  /// Un jeton Google refusé n'est pas un mot de passe erroné : il se dit
  /// comme un échec de Google ([AuthFailure.googleSignInFailed]).
  Future<User?> signInWithGoogle() async {
    try {
      return await _guard(() async {
        final credential = await _googleCredential();
        final result = await _timed(_auth.signInWithCredential(credential));
        return result.user;
      });
    } on AuthFailure catch (failure, stackTrace) {
      if (failure != AuthFailure.invalidCredentials) rethrow;
      Error.throwWithStackTrace(AuthFailure.googleSignInFailed, stackTrace);
    }
  }

  Future<User?> signInAnonymously() => _guard(() async {
    final credential = await _auth.signInAnonymously();
    return credential.user;
  });

  /// Ouvre le compte Google que l'utilisateur vient de choisir (celui d'une
  /// liaison refusée, repris sans sélecteur quand Google le connaît encore ;
  /// sinon le sélecteur s'ouvre). [prepare] reçoit son adresse pendant que la
  /// session courante est encore ouverte : s'il renvoie false, rien ne
  /// s'ouvre et le résultat est null.
  Future<User?> signInWithGoogleAccount(
    Future<bool> Function(String email) prepare,
  ) async {
    try {
      return await _guard(() async {
        final googleUser =
            await _googleSignIn.attemptLightweightAuthentication() ??
            await _googleSignIn.authenticate(scopeHint: ['email']);
        final credential = await _credentialFor(googleUser);
        if (!await prepare(googleUser.email)) return null;
        return (await _auth.signInWithCredential(credential)).user;
      });
    } on AuthFailure catch (failure, stackTrace) {
      // Comme à la connexion : un jeton Google refusé n'est pas un mot de passe.
      if (failure != AuthFailure.invalidCredentials) rethrow;
      Error.throwWithStackTrace(AuthFailure.googleSignInFailed, stackTrace);
    }
  }

  /// Lie le compte invité courant au compte Google choisi : même uid, mêmes
  /// données. Sans nom, le compte prend celui du compte Google, que le profil
  /// reprendra. Un compte Google déjà connu d'AnKi est refusé
  /// ([AuthFailure.credentialAlreadyInUse]), comme une adresse qui est déjà
  /// celle d'un compte e-mail ([AuthFailure.emailAlreadyInUse]), sans rien
  /// changer.
  Future<User?> linkCurrentUserWithGoogle() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);
    final credential = await _credentialFor(googleUser);
    final linked = (await user.linkWithCredential(credential)).user;
    final googleName = googleUser.displayName?.trim() ?? '';
    if (linked != null &&
        (linked.displayName?.trim() ?? '').isEmpty &&
        googleName.isNotEmpty) {
      try {
        await linked.updateDisplayName(googleName);
        await linked.reload();
      } on FirebaseAuthException {
        // Au mieux : la liaison est faite, un nom manquant ne la défait pas
        // (le profil garde alors ses noms vides, l'accueil salue sans nom).
      }
    }
    return _auth.currentUser;
  });

  Future<AuthCredential> _googleCredential() async =>
      _credentialFor(await _googleSignIn.authenticate(scopeHint: ['email']));

  Future<AuthCredential> _credentialFor(GoogleSignInAccount googleUser) async {
    final googleAuth = googleUser.authentication;
    final authorization = await googleUser.authorizationClient.authorizeScopes([
      'email',
    ]);
    return GoogleAuthProvider.credential(
      accessToken: authorization.accessToken,
      idToken: googleAuth.idToken,
    );
  }

  Future<void> signOutFirebase() => _auth.signOut();

  Future<void> signOutGoogle() => _googleSignIn.signOut();

  /// Confirme l'identité du compte Google connecté : le sélecteur Google
  /// s'ouvre, le compte choisi doit être le même
  /// ([AuthFailure.userMismatch] sinon). Sans session, rien.
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _guard(() async {
        await user.reauthenticateWithCredential(await _googleCredential());
      });
    } on AuthFailure catch (failure, stackTrace) {
      // Comme à la connexion : un jeton Google refusé n'est pas un mot de passe.
      if (failure != AuthFailure.invalidCredentials) rethrow;
      Error.throwWithStackTrace(AuthFailure.googleSignInFailed, stackTrace);
    }
  }

  /// Confirme l'identité du compte e-mail connecté avec [password]. Sans
  /// session, rien ; sans adresse, rien ne la confirme
  /// ([AuthFailure.requiresRecentLogin]).
  Future<void> reauthenticateWithPassword(String password) => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final email = user.email;
    if (email == null) throw AuthFailure.requiresRecentLogin;
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  });

  /// Supprime le compte connecté ; refusé ([AuthFailure.requiresRecentLogin])
  /// si sa connexion est trop ancienne.
  Future<void> deleteCurrentUser() => _guard(() async {
    await _auth.currentUser?.delete();
  });

  /// Écrit (ou efface avec null) le token biométrique sur le document utilisateur.
  Future<void> setBiometricToken(String uid, String? token) =>
      _users.doc(uid).set({'biometricToken': token}, SetOptions(merge: true));

  /// Indique si [token] correspond à celui stocké sur le document utilisateur.
  Future<bool> isBiometricTokenValid(String uid, String token) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return false;
    return (doc.data()?['biometricToken'] as String?) == token;
  }

  /// [call] de connexion borné par `_signInTimeout`. Firebase peut encore
  /// aboutir après coup : la session s'ouvre alors d'elle-même
  /// ([userChanges]), sans passer le verrou biométrique ni noter de connexion
  /// explicite ; un nouvel essai le fait. Si une autre connexion a réussi
  /// entre-temps, celle-ci la remplace.
  Future<T> _timed<T>(Future<T> call) async {
    try {
      return await call.timeout(_signInTimeout);
    } on TimeoutException catch (_, stackTrace) {
      Error.throwWithStackTrace(AuthFailure.signInTimeout, stackTrace);
    }
  }

  /// Exécute un appel Firebase Auth en traduisant ses refus en [AuthFailure],
  /// pile d'appel conservée.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FirebaseAuthException catch (error, stackTrace) {
      Error.throwWithStackTrace(_failureFor(error.code), stackTrace);
    }
  }
}

AuthFailure _failureFor(String code) => switch (code) {
  'weak-password' => AuthFailure.weakPassword,
  'email-already-in-use' => AuthFailure.emailAlreadyInUse,
  'credential-already-in-use' => AuthFailure.credentialAlreadyInUse,
  'invalid-email' => AuthFailure.invalidEmail,
  'user-not-found' => AuthFailure.userNotFound,
  'wrong-password' => AuthFailure.wrongPassword,
  'invalid-credential' => AuthFailure.invalidCredentials,
  'network-request-failed' => AuthFailure.network,
  'too-many-requests' => AuthFailure.tooManyRequests,
  'user-disabled' => AuthFailure.userDisabled,
  'user-mismatch' => AuthFailure.userMismatch,
  'requires-recent-login' => AuthFailure.requiresRecentLogin,
  _ => AuthFailure.unknown,
};

/// SDK Google Sign-In, initialisé une fois dans `main()`. Propre à `auth`.
final googleSignInProvider = Provider<GoogleSignIn>(
  (ref) => GoogleSignIn.instance,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    googleSignIn: ref.watch(googleSignInProvider),
    firestore: ref.watch(firestoreProvider),
  ),
);
