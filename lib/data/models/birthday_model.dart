import 'package:cloud_firestore/cloud_firestore.dart';

enum BirthdayCategory { family, friend, colleague }

class BirthdayModel {
  final String id;
  final String name;
  final String surname;
  final DateTime date;
  final BirthdayCategory? category;

  const BirthdayModel({
    required this.id,
    required this.name,
    required this.surname,
    required this.date,
    this.category,
  });

  factory BirthdayModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return BirthdayModel(
      id: doc.id,
      name: data['name'],
      surname: data['surname'],
      date: (data['date'] as Timestamp).toDate(),
      category: data['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "surname": surname,
      "date": Timestamp.fromDate(date),
      "category": null,
    };
  }
}
