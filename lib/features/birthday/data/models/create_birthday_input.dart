import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class CreateBirthdayInput {
  const CreateBirthdayInput({
    required this.uid,
    required this.name,
    required this.surname,
    required this.date,
    required this.categories,
    this.pictureFile,
  });

  final String uid;
  final String name;
  final String surname;
  final DateTime date;
  final List<String> categories;
  final XFile? pictureFile;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name.trim(),
      'surname': surname.trim(),
      'date': Timestamp.fromDate(date),
      'categories': categories,
    };
  }

  CreateBirthdayInput copyWith({
    String? uid,
    String? name,
    String? surname,
    DateTime? date,
    List<String>? categories,
    XFile? pictureFile,
  }) {
    return CreateBirthdayInput(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      date: date ?? this.date,
      categories: categories ?? this.categories,
      pictureFile: pictureFile ?? this.pictureFile,
    );
  }
}
