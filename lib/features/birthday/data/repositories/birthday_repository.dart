import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/features/birthday/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/data/models/create_birthday_input.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BirthdayRepository {
  final FirebaseFirestore? _firestoreOverride;

  BirthdayRepository({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _birthdays =>
      _firestore.collection('birthday');

  Stream<List<BirthdayModel>> watchBirthdays(String uid) {
    return _birthdays
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) =>
              snapshot.docs.map(BirthdayModel.fromFirestore).toList(),
        );
  }

  Future<void> createBirthday(String uid, CreateBirthdayInput input) async {
    final Map<String, dynamic> data = input.toJson();
    data['uid'] = uid;

    if (input.pictureFile != null) {
      final Uint8List bytes = await input.pictureFile!.readAsBytes();
      data['picture'] = base64Encode(bytes);
    }

    await _birthdays.add(data);
  }

  Future<void> updateBirthday(
    String uid,
    String birthdayId,
    CreateBirthdayInput input,
  ) async {
    final Map<String, dynamic> data = input.toJson();
    data['uid'] = uid;

    if (input.pictureFile != null) {
      final Uint8List bytes = await input.pictureFile!.readAsBytes();
      data['picture'] = base64Encode(bytes);
    }

    await _birthdays.doc(birthdayId).update(data);
  }

  Future<void> deleteBirthday(String uid, String birthdayId) async {
    final doc = await _birthdays.doc(birthdayId).get();
    if (doc.exists && doc.data()?['uid'] == uid) {
      await _birthdays.doc(birthdayId).delete();
    }
  }

  Future<void> deleteAllUserBirthdays(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _birthdays.where('uid', isEqualTo: uid).get();

    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

final birthdayRepositoryProvider = Provider<BirthdayRepository>(
  (ref) => BirthdayRepository(),
);
