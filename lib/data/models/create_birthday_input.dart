import 'package:an_ki/data/models/birthday_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateBirthdayInput {
  const CreateBirthdayInput({
    required this.name,
    required this.surname,
    required this.date,
    required this.category,
  });

  final String name;
  final String surname;
  final DateTime date;
  final BirthdayCategory category;

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'surname': surname.trim(),
      'date': Timestamp.fromDate(date),
      'category': category.name,
    };
  }
}

