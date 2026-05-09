import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String surname;
  final String? pseudo;

  const UserModel({
    required this.id,
    required this.name,
    required this.surname,
    this.pseudo,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data()!;

    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      surname: data['surname'] ?? '',
      pseudo: data['pseudo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'surname': surname,
      if (pseudo != null) 'pseudo': pseudo,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? surname,
    String? pseudo,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      pseudo: pseudo ?? this.pseudo,
    );
  }
}
