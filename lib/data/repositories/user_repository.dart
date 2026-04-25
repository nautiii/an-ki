import 'package:an_ki/data/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository {
  final CollectionReference<Map<String, dynamic>> _users = FirebaseFirestore
      .instance
      .collection('user');

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
