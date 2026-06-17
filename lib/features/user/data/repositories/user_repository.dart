import 'package:an_ki/features/user/data/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserRepository {
  final FirebaseFirestore? _firestoreOverride;

  UserRepository({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('user');

  Future<UserModel?> fetchUser(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _users.doc(uid).get();

    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  /// Creates the user document **only if it does not already exist**.
  ///
  /// Runs inside a transaction so that a failed/stale read upstream can never
  /// overwrite an existing profile (pseudo, biometric token, categories...).
  /// A crash during login must never destroy data.
  ///
  /// Returns the effective user: the already-stored document when present,
  /// otherwise the freshly created [user].
  Future<UserModel> createUser(UserModel user) async {
    final DocumentReference<Map<String, dynamic>> docRef = _users.doc(user.id);

    return _firestore.runTransaction<UserModel>((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(docRef);

      if (snapshot.exists) {
        return UserModel.fromFirestore(snapshot);
      }

      transaction.set(docRef, user.toJson());
      return user;
    });
  }

  Future<void> updateUser(UserModel user) async {
    await _users.doc(user.id).update(user.toJson());
  }

  Future<void> updateBiometricToken(String uid, String? token) async {
    await _users.doc(uid).update({'biometricToken': token});
  }

  Future<UserModel?> fetchUserByToken(String uid, String token) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;

    final user = UserModel.fromFirestore(doc);
    if (user.biometricToken == token) {
      return user;
    }
    return null;
  }

  Future<void> deleteUser(String uid) async {
    await _users.doc(uid).delete();
  }
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);
