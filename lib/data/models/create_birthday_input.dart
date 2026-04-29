import 'package:an_ki/data/models/birthday_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class CreateBirthdayInput {
  const CreateBirthdayInput({
    required this.uid,
    required this.name,
    required this.surname,
    required this.date,
    required this.category,
    this.pictureFile,
  });

  final String uid;
  final String name;
  final String surname;
  final DateTime date;
  final BirthdayCategory category;
  final XFile? pictureFile;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name.trim(),
      'surname': surname.trim(),
      'date': Timestamp.fromDate(date),
      'category': category.name,
    };
  }
}
