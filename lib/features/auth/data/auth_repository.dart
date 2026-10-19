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
  });

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

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
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  });

  Future<User?> signInWithGoogle() => _guard(() async {
    final credential = await _googleCredential();
    final result = await _auth.signInWithCredential(credential);
    return result.user;
  });

  Future<User?> signInAnonymously() => _guard(() async {
    final credential = await _auth.signInAnonymously();
    return credential.user;
  });

  /// Lie le compte invité courant au compte Google choisi : même uid, mêmes
  /// données. Sans nom, le compte prend celui du compte Google, que le profil
  /// reprendra. Un compte Google déjà connu d'AnKi est refusé
  /// ([AuthFailure.credentialAlreadyInUse]) sans rien changer.
  Future<User?> linkCurrentUserWithGoogle() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);
    final credential = await _credentialFor(googleUser);
    final User? linked;
    try {
      linked = (await user.linkWithCredential(credential)).user;
    } on FirebaseAuthException catch (error, stackTrace) {
      // Son adresse est déjà celle d'un compte AnKi par e-mail : même refus.
      if (error.code == 'email-already-in-use') {
        Error.throwWithStackTrace(
          AuthFailure.credentialAlreadyInUse,
          stackTrace,
        );
      }
      rethrow;
    }
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
