import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late BirthdayRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = BirthdayRepository(firestore: firestore);
  });

  BirthdayDraft draft({String name = 'Alice', Uint8List? picture}) =>
      BirthdayDraft(
        name: name,
        surname: 'Wonderland',
        date: DateTime(1990, 5, 10),
        categories: const ['family'],
        picture: picture,
      );

  Future<DocumentReference<Map<String, dynamic>>> seed(
    Map<String, dynamic> data,
  ) => firestore.collection('birthday').add(data);

  Future<Map<String, dynamic>> stored(String id) async =>
      (await firestore.collection('birthday').doc(id).get()).data()!;

  group('watchBirthdays', () {
    test('only emits birthdays belonging to the given uid', () async {
      await seed({
        'uid': 'user-1',
        'name': 'Mine',
        'surname': 'X',
        'date': Timestamp.fromDate(DateTime(1990)),
        'categories': <String>[],
      });
      await seed({
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

    test('maps every field, decoding the picture', () async {
      final ref = await seed({
        'uid': 'user-1',
        'name': 'Alice',
        'surname': 'Wonderland',
        'date': Timestamp.fromDate(DateTime(1990, 5, 10)),
        'categories': ['family', 'friend'],
        'picture': base64Encode([1, 2, 3]),
      });

      final birthdays = await repository.watchBirthdays('user-1').first;

      expect(birthdays, [
        Birthday(
          id: ref.id,
          name: 'Alice',
          surname: 'Wonderland',
          date: DateTime(1990, 5, 10),
          categories: const ['family', 'friend'],
          picture: Uint8List.fromList([1, 2, 3]),
        ),
      ]);
    });

    test('applies defaults to an old document missing fields', () async {
      final ref = await seed({
        'uid': 'user-1',
        'date': Timestamp.fromDate(DateTime(1985)),
      });

      final birthdays = await repository.watchBirthdays('user-1').first;

      expect(birthdays, [
        Birthday(id: ref.id, name: '', surname: '', date: DateTime(1985)),
      ]);
    });

    test('drops an undecodable picture', () async {
      await seed({
        'uid': 'user-1',
        'name': 'Alice',
        'date': Timestamp.fromDate(DateTime(1990)),
        'picture': '!!not base64!!',
      });

      final birthday = (await repository.watchBirthdays('user-1').first).single;

      expect(birthday.picture, isNull);
    });

    test('skips a document without a date instead of failing', () async {
      await seed({'uid': 'user-1', 'name': 'Broken'});
      await seed({
        'uid': 'user-1',
        'name': 'Fine',
        'date': Timestamp.fromDate(DateTime(1990)),
      });

      final birthdays = await repository.watchBirthdays('user-1').first;

      expect(birthdays.map((b) => b.name), ['Fine']);
    });
  });

  group('createBirthday', () {
    test('stores the trimmed draft with the uid', () async {
      await repository.createBirthday(
        'user-1',
        draft(name: '  Alice  ').copyWith(surname: ' Wonderland '),
      );

      final doc = (await firestore.collection('birthday').get()).docs.single;
      expect(doc.data(), {
        'uid': 'user-1',
        'name': 'Alice',
        'surname': 'Wonderland',
        'date': Timestamp.fromDate(DateTime(1990, 5, 10)),
        'categories': ['family'],
      });
    });

    test('encodes the picture as base64 when provided', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      await repository.createBirthday('user-1', draft(picture: bytes));

      final doc = (await firestore.collection('birthday').get()).docs.single;
      expect(doc.data()['picture'], base64Encode(bytes));
    });
  });

  group('updateBirthday', () {
    test('overwrites the stored fields', () async {
      final ref = await seed({
        'uid': 'user-1',
        'name': 'Old',
        'surname': 'X',
        'date': Timestamp.fromDate(DateTime(1990)),
        'categories': <String>[],
      });

      await repository.updateBirthday('user-1', ref.id, draft(name: 'Updated'));

      expect((await stored(ref.id))['name'], 'Updated');
    });

    test('keeps the stored picture when the draft has none', () async {
      final ref = await seed({
        'uid': 'user-1',
        'name': 'Old',
        'date': Timestamp.fromDate(DateTime(1990)),
        'picture': 'kept',
      });

      await repository.updateBirthday('user-1', ref.id, draft());

      expect((await stored(ref.id))['picture'], 'kept');
    });

    test('encodes a new picture when provided', () async {
      final ref = await seed({
        'uid': 'user-1',
        'name': 'Old',
        'date': Timestamp.fromDate(DateTime(1990)),
      });
      final bytes = Uint8List.fromList([9, 9, 9]);

      await repository.updateBirthday('user-1', ref.id, draft(picture: bytes));

      expect((await stored(ref.id))['picture'], base64Encode(bytes));
    });
  });

  group('deleteBirthday', () {
    test('deletes a birthday owned by the uid', () async {
      final ref = await seed({
        'uid': 'user-1',
        'name': 'X',
        'surname': 'Y',
        'date': Timestamp.fromDate(DateTime(1990)),
        'categories': <String>[],
      });

      await repository.deleteBirthday(ref.id);

      final doc = await firestore.collection('birthday').doc(ref.id).get();
      expect(doc.exists, isFalse);
    });
    // La propriété du document est vérifiée par les règles Firestore
    // (`firestore.rules`), pas par une lecture préalable côté client.
  });

  group('createBirthdays', () {
    test('stores every draft with the uid', () async {
      await repository.createBirthdays('user-1', [
        draft(name: 'A'),
        draft(name: 'B'),
      ]);

      final docs = (await firestore.collection('birthday').get()).docs;
      expect(docs.map((d) => d.data()['name']), ['A', 'B']);
      expect(docs.map((d) => d.data()['uid']).toSet(), {'user-1'});
    });

    test('splits more than 500 writes into several batches', () async {
      await repository.createBirthdays('user-1', [
        for (var i = 0; i < 501; i++) draft(name: 'P$i'),
      ]);

      final docs = (await firestore.collection('birthday').get()).docs;
      expect(docs, hasLength(501));
    });
  });

  group('deleteAllUserBirthdays', () {
    test('removes every birthday for the uid only', () async {
      for (var i = 0; i < 3; i++) {
        await seed({
          'uid': 'user-1',
          'name': 'N$i',
          'surname': 'X',
          'date': Timestamp.fromDate(DateTime(1990)),
          'categories': <String>[],
        });
      }
      await seed({
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

    test('erases more than 500 birthdays', () async {
      await repository.createBirthdays('user-1', [
        for (var i = 0; i < 501; i++) draft(name: 'P$i'),
      ]);

      await repository.deleteAllUserBirthdays('user-1');

      final remaining = await firestore.collection('birthday').get();
      expect(remaining.docs, isEmpty);
    });
  });
}
