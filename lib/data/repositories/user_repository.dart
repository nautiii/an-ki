import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class UserRepository {
  final CollectionReference<Map<String, dynamic>> _users = FirebaseFirestore
      .instance
      .collection('user');

  Future<UserModel?> fetchUser({
    required String name,
    required String surname,
  }) async {
    final query =
        await _users
            .where('name', isEqualTo: name)
            .where('surname', isEqualTo: surname)
            .limit(1)
            .get();

    return query.docs.isEmpty
        ? null
        : UserModel.fromFirestore(query.docs.first);
  }
}
