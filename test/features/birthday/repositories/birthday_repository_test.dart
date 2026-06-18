import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/features/birthday/data/models/create_birthday_input.dart';
import 'package:an_ki/features/birthday/data/repositories/birthday_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late BirthdayRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = BirthdayRepository(firestore: firestore);
  });

  CreateBirthdayInput input({
    String uid = 'user-1',
    String name = 'Alice',
    XFile? picture,
  }) => CreateBirthdayInput(
    uid: uid,
    name: name,
    surname: 'Wonderland',
    date: DateTime(1990, 5, 10),
    categories: const ['family'],
    pictureFile: picture,
  );

  group('watchBirthdays', () {
    test('only emits birthdays belonging to the given uid', () async {
      await firestore.collection('birthday').add({
        'uid': 'user-1',
        'name': 'Mine',
        'surname': 'X',
        'date': Timestamp.fromDate(DateTime(1990)),
        'categories': <String>[],
      });
      await firestore.collection('birthday').add({
        'uid': 'user-2',
        'name': 'Other',
        'surname': 'Y',
        'date': Timestamp.fromDate(DateTime(1990)),
        'categories': <String>[],
      });

      final birthdays = await repository.watchBirthdays('user-1').first;

      expect(birthdays, hasLength(1));
      expect(birthdays.single.name, 'Mine');
    });
  });

  group('createBirthday', () {
    test('stores the document with the uid', () async {
      await repository.createBirthday('user-1', input());

      final docs = await firestore.collection('birthday').get();
      expect(docs.docs, hasLength(1));
      expect(docs.docs.single.data()['uid'], 'user-1');
      expect(docs.docs.single.data()['name'], 'Alice');
      expect(docs.docs.single.data().containsKey('picture'), isFalse);
    });

    test('encodes the picture file as base64 when provided', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      await repository.createBirthday(
        'user-1',
        input(picture: XFile.fromData(bytes)),
      );

      final doc = (await firestore.collection('birthday').get()).docs.single;
      expect(doc.data()['picture'], base64Encode(bytes));
    });
  });

  group('updateBirthday', () {
    test('overwrites the stored fields', () async {
      final ref = await firestore.collection('birthday').add({
        'uid': 'user-1',
        'name': 'Old',
        'surname': 'X',
        'date': Timestamp.fromDate(DateTime(1990)),
        'categories': <String>[],
      });

      await repository.updateBirthday('user-1', ref.id, input(name: 'Updated'));

      final doc = await firestore.collection('birthday').doc(ref.id).get();
      expect(doc.data()!['name'], 'Updated');
    });

    test('encodes the picture file when provided', () async {
      final ref = await firestore.collection('birthday').add({
        'uid': 'user-1',
        'name': 'Old',
        'surname': 'X',
        'date': Timestamp.fromDate(DateTime(1990)),
        'categories': <String>[],
      });
      final bytes = Uint8List.fromList([9, 9, 9]);

      await repository.updateBirthday(
        'user-1',
        ref.id,
        input(picture: XFile.fromData(bytes)),
      );

      final doc = await firestore.collection('birthday').doc(ref.id).get();
      expect(doc.data()!['picture'], base64Encode(bytes));
    });
  });

  group('deleteBirthday', () {
    test('deletes a birthday owned by the uid', () async {
      final ref = await firestore.collection('birthday').add({
        'uid': 'user-1',
        'name': 'X',
        'surname': 'Y',
        'date': Timestamp.fromDate(DateTime(1990)),
        'categories': <String>[],
      });

      await repository.deleteBirthday('user-1', ref.id);

      final doc = await firestore.collection('birthday').doc(ref.id).get();
      expect(doc.exists, isFalse);
    });

    test('does not delete a birthday owned by someone else', () async {
      final ref = await firestore.collection('birthday').add({
        'uid': 'user-2',
        'name': 'X',
        'surname': 'Y',
        'date': Timestamp.fromDate(DateTime(1990)),
        'categories': <String>[],
      });

      await repository.deleteBirthday('user-1', ref.id);

      final doc = await firestore.collection('birthday').doc(ref.id).get();
      expect(doc.exists, isTrue);
    });
  });

  group('deleteAllUserBirthdays', () {
    test('removes every birthday for the uid only', () async {
      for (var i = 0; i < 3; i++) {
        await firestore.collection('birthday').add({
          'uid': 'user-1',
          'name': 'N$i',
          'surname': 'X',
          'date': Timestamp.fromDate(DateTime(1990)),
          'categories': <String>[],
        });
      }
      await firestore.collection('birthday').add({
        'uid': 'user-2',
        'name': 'Keep',
        'surname': 'X',
        'date': Timestamp.fromDate(DateTime(1990)),
        'categories': <String>[],
      });

      await repository.deleteAllUserBirthdays('user-1');

      final remaining = await firestore.collection('birthday').get();
      expect(remaining.docs, hasLength(1));
      expect(remaining.docs.single.data()['uid'], 'user-2');
    });
  });
}
