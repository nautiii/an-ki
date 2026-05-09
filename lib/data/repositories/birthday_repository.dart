import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/create_birthday_input.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BirthdayRepository {
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseStorage? _storageOverride;

  BirthdayRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestoreOverride = firestore,
      _storageOverride = storage;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _birthdays =>
      _firestore.collection('birthday');

  Reference get _storageRef => _storage.ref().child('birthdays');

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
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storageRef.child(fileName);
      final Uint8List bytes = await input.pictureFile!.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      data['picture'] = await ref.getDownloadURL();
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

  Future<void> deleteBirthday(String birthdayId) async {
    await _birthdays.doc(birthdayId).delete();
  }
}

final birthdayRepositoryProvider = Provider<BirthdayRepository>(
  (ref) => BirthdayRepository(),
);
