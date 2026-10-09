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

  Stream<User?> authStateChanges() => _auth.authStateChanges();

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

  Future<User?> linkCurrentUserWithGoogle() => _guard(() async {
    final credential = await _googleCredential();
    final result = await _auth.currentUser?.linkWithCredential(credential);
    return result?.user;
  });

  Future<AuthCredential> _googleCredential() async {
    final googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);
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
  'invalid-email' => AuthFailure.invalidEmail,
  'user-not-found' => AuthFailure.userNotFound,
  'wrong-password' => AuthFailure.wrongPassword,
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
