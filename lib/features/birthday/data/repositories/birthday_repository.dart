import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/features/birthday/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/data/models/create_birthday_input.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BirthdayRepository {
  BirthdayRepository({required this._firestore});

  final FirebaseFirestore _firestore;

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

  /// Crée plusieurs anniversaires sans photo (import de contacts), par lots de
  /// [_batchLimit] écritures. Tous les lots partent d'un coup : Firestore les
  /// applique au cache local immédiatement, le Future attend le serveur.
  Future<void> createBirthdays(String uid, List<CreateBirthdayInput> inputs) {
    final commits = <Future<void>>[];
    for (var start = 0; start < inputs.length; start += _batchLimit) {
      final batch = _firestore.batch();
      for (final input in inputs.skip(start).take(_batchLimit)) {
        batch.set(_birthdays.doc(), {...input.toJson(), 'uid': uid});
      }
      commits.add(batch.commit());
    }
    return Future.wait(commits);
  }

  /// Limite Firestore d'écritures par lot.
  static const _batchLimit = 500;

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

  /// Supprime un anniversaire. La propriété du document est vérifiée par les
  /// règles Firestore : pas de lecture préalable, qui retarderait l'écriture.
  Future<void> deleteBirthday(String birthdayId) =>
      _birthdays.doc(birthdayId).delete();

  Future<void> deleteAllUserBirthdays(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _birthdays
        .where('uid', isEqualTo: uid)
        .get();

    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

final birthdayRepositoryProvider = Provider<BirthdayRepository>(
  (ref) => BirthdayRepository(firestore: ref.watch(firestoreProvider)),
);
