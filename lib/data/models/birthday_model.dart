import 'package:cloud_firestore/cloud_firestore.dart';

class BirthdayModel {
  final String id;
  final String uid;
  final String name;
  final String surname;
  final DateTime date;
  final List<String> categories;
  final String? picture;

  const BirthdayModel({
    required this.id,
    required this.uid,
    required this.name,
    required this.surname,
    required this.date,
    required this.categories,
    this.picture,
  });

  factory BirthdayModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final categoriesData = data['categories'] as List<dynamic>? ?? [];

    return BirthdayModel(
      id: doc.id,
      uid: data['uid'],
      name: data['name'],
      surname: data['surname'],
      date: (data['date'] as Timestamp).toDate(),
      categories: categoriesData.map((c) => c as String).toList(),
      picture: data['picture'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'surname': surname,
      'date': Timestamp.fromDate(date),
      'categories': categories,
      if (picture != null) 'picture': picture,
    };
  }
}
