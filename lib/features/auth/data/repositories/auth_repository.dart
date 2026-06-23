import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Couche data de l'authentification.
///
/// Encapsule les SDK Firebase Auth + Google Sign-In et persiste le token
/// biométrique sur le document utilisateur. N'embarque aucune logique métier et
/// ne mappe aucune erreur — les exceptions remontent au Notifier. Garde la
/// feature `auth` découplée de la feature `user`.
class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

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
  }) async {
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
  }

  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  Future<User?> signInWithGoogle() async {
    final credential = await _googleCredential();
    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  Future<User?> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    return credential.user;
  }

  Future<User?> linkCurrentUserWithGoogle() async {
    final credential = await _googleCredential();
    final result = await _auth.currentUser?.linkWithCredential(credential);
    return result?.user;
  }

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

  Future<void> deleteCurrentUser() async {
    await _auth.currentUser?.delete();
  }

  /// Écrit (ou efface avec null) le token biométrique sur le document utilisateur.
  Future<void> setBiometricToken(String uid, String? token) =>
      _users.doc(uid).set({'biometricToken': token}, SetOptions(merge: true));

  /// Indique si [token] correspond à celui stocké sur le document utilisateur.
  Future<bool> isBiometricTokenValid(String uid, String token) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return false;
    return (doc.data()?['biometricToken'] as String?) == token;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);
