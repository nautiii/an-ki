import 'package:an_ki/data/models/birthday_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/create_birthday_input.dart';

class BirthdayRepository {
  final CollectionReference<Map<String, dynamic>> _birthdays = FirebaseFirestore
      .instance
      .collection('birthday');

  Stream<List<BirthdayModel>> watchBirthdays() {
    return _birthdays.snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) =>
          snapshot.docs.map(BirthdayModel.fromFirestore).toList(),
    );
  }

  Future<void> createBirthday(CreateBirthdayInput input) async {
    await _birthdays.add(input.toJson());
  }
}
