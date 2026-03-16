import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String surname;

  const UserModel({
    required this.id,
    required this.name,
    required this.surname,
  });

  factory UserModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return UserModel(id: doc.id, name: data['name'], surname: data['surname']);
  }
}
