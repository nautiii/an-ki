import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum BirthdayCategory { family, friend, colleague, other }

class BirthdayModel {
  final String id;
  final String name;
  final String surname;
  final DateTime date;
  final BirthdayCategory category;
  final String? picture;

  const BirthdayModel({
    required this.id,
    required this.name,
    required this.surname,
    required this.date,
    required this.category,
    this.picture,
  });

  factory BirthdayModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();

    return BirthdayModel(
      id: doc.id,
      name: data['name'],
      surname: data['surname'],
      date: (data['date'] as Timestamp).toDate(),
      category: (data['category'] as String).toBirthdayCategory(),
      picture: data['picture'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'surname': surname,
      'date': Timestamp.fromDate(date),
      'category': category.name,
      if (picture != null) 'picture': picture,
    };
  }
}
