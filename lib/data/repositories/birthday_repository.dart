import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/create_birthday_input.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class BirthdayRepository {
  final CollectionReference<Map<String, dynamic>> _birthdays = FirebaseFirestore
      .instance
      .collection('birthday');
  final Reference _storageRef = FirebaseStorage.instance.ref().child(
    'birthdays',
  );

  Stream<List<BirthdayModel>> watchBirthdays() {
    return _birthdays.snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) =>
          snapshot.docs.map(BirthdayModel.fromFirestore).toList(),
    );
  }

  Future<void> createBirthday(CreateBirthdayInput input) async {
    final Map<String, dynamic> data = input.toJson();

    if (input.pictureFile != null) {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storageRef.child(fileName);
      final Uint8List bytes = await input.pictureFile!.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      data['picture'] = await ref.getDownloadURL();
    }

    await _birthdays.add(data);
  }

  Future<void> updateBirthday(
    String birthdayId,
    CreateBirthdayInput input,
  ) async {
    final Map<String, dynamic> data = input.toJson();

    if (input.pictureFile != null) {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      // final Reference ref = _storageRef.child(fileName);
      final Uint8List bytes = await input.pictureFile!.readAsBytes();
      // String base64 = base64Encode(bytes);
      // await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      data['picture'] = base64Encode(bytes); // await ref.getDownloadURL();
    }

    await _birthdays.doc(birthdayId).update(data);
  }
}
