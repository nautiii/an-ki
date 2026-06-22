import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Data layer for authentication.
///
/// Wraps the Firebase Auth + Google Sign-In SDKs and persists the biometric
/// token on the user document. Owns no business logic and maps no errors —
/// exceptions bubble up to the Notifier. Keeps the `auth` feature decoupled
/// from the `user` feature.
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

  // ── Session ───────────────────────────────────────────────────────────────

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // ── Sign-in / sign-up ───────────────────────────────────────────────────

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

  // ── Sign-out / delete ─────────────────────────────────────────────────────

  Future<void> signOutFirebase() => _auth.signOut();

  Future<void> signOutGoogle() => _googleSignIn.signOut();

  Future<void> deleteCurrentUser() async {
    await _auth.currentUser?.delete();
  }

  // ── Biometric token (persisted on the user document) ──────────────────────

  /// Writes (or clears with null) the biometric token on the user document.
  Future<void> setBiometricToken(String uid, String? token) =>
      _users.doc(uid).set({'biometricToken': token}, SetOptions(merge: true));

  /// Whether [token] matches the one stored on the user document.
  Future<bool> isBiometricTokenValid(String uid, String token) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return false;
    return (doc.data()?['biometricToken'] as String?) == token;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);
