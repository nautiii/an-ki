import 'package:an_ki/data/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserRepository {
  final FirebaseFirestore? _firestoreOverride;

  UserRepository({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<UserModel?> fetchUser(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _users.doc(uid).get();

    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  Future<void> createUser(UserModel user) async {
    await _users.doc(user.id).set(user.toJson());
  }

  Future<void> updateUser(UserModel user) async {
    await _users.doc(user.id).update(user.toJson());
  }
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);
