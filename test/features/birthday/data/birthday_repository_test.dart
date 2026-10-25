import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
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

  BirthdayDraft draft({
    String name = 'Alice',
    String surname = 'Wonderland',
    BirthDate date = const BirthDate(year: 1990, month: 5, day: 10),
    Uint8List? picture,
    Set<ReminderLead>? reminders,
  }) => BirthdayDraft(
    name: name,
    surname: surname,
    date: date,
    categories: const ['family'],
    picture: picture,
    reminders: reminders,
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
          date: BirthDate.fromDate(DateTime(1990, 5, 10)),
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
        Birthday(
          id: ref.id,
          name: '',
          surname: '',
          date: BirthDate.fromDate(DateTime(1985)),
        ),
      ]);
    });

    test('leaves out a year flagged unknown', () async {
      await seed({
        'uid': 'user-1',
        'name': 'Mamie',
        'date': Timestamp.fromDate(DateTime(2000, 10, 15)),
        'yearKnown': false,
      });

      final birthday = (await repository.watchBirthdays('user-1').first).single;

      expect(birthday.date, const BirthDate(month: 10, day: 15));
    });

    test('reads the years wished, skipping what is not a year', () async {
      await seed({
        'uid': 'user-1',
        'name': 'Alice',
        'date': Timestamp.fromDate(DateTime(1990)),
        'wishedYears': [2024, 'oops', 2026],
      });

      final birthday = (await repository.watchBirthdays('user-1').first).single;

      expect(birthday.wishedYears, [2024, 2026]);
    });

    test('reads own reminders, skipping an unknown lead', () async {
      await seed({
        'uid': 'user-1',
        'date': Timestamp.fromDate(DateTime(1990, 5, 10)),
        'reminders': ['dayBefore', 'hourBefore', 'sameDay'],
      });
      await seed({
        'uid': 'user-1',
        'date': Timestamp.fromDate(DateTime(1991, 5, 10)),
        'reminders': <String>[],
      });

      final birthdays = await repository.watchBirthdays('user-1').first;

      expect(birthdays.map((b) => b.reminders), [
        {ReminderLead.dayBefore, ReminderLead.sameDay},
        // Liste vide : aucun rappel, pas le réglage par défaut.
        isEmpty,
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
        draft(name: '  Alice  ', surname: ' Wonderland '),
      );

      final doc = (await firestore.collection('birthday').get()).docs.single;
      expect(doc.data(), {
        'uid': 'user-1',
        'name': 'Alice',
        'surname': 'Wonderland',
        'date': Timestamp.fromDate(DateTime(1990, 5, 10)),
        'yearKnown': true,
        'categories': ['family'],
      });
    });

    test('stores a missing year as a leap year flagged unknown', () async {
      await repository.createBirthday(
        'user-1',
        draft(date: const BirthDate(month: 2, day: 29)),
      );

      final doc = (await firestore.collection('birthday').get()).docs.single;
      expect(doc.data()['date'], Timestamp.fromDate(DateTime(2000, 2, 29)));
      expect(doc.data()['yearKnown'], false);
    });

    test('encodes the picture as base64 when provided', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      await repository.createBirthday('user-1', draft(picture: bytes));

      final doc = (await firestore.collection('birthday').get()).docs.single;
      expect(doc.data()['picture'], base64Encode(bytes));
    });
  });

  group('own reminders', () {
    test('are left out of a birthday following the default', () async {
      await repository.createBirthday('user-1', draft());

      final doc = (await firestore.collection('birthday').get()).docs.single;
      expect(doc.data().containsKey('reminders'), isFalse);
    });

    test('are stored by name, earliest first', () async {
      await repository.createBirthday(
        'user-1',
        draft(reminders: {ReminderLead.sameDay, ReminderLead.monthBefore}),
      );

      final doc = (await firestore.collection('birthday').get()).docs.single;
      expect(doc.data()['reminders'], ['monthBefore', 'sameDay']);
    });

    test('are erased when a birthday goes back to the default', () async {
      final ref = await seed({
        'uid': 'user-1',
        'name': 'Old',
        'date': Timestamp.fromDate(DateTime(1990)),
        'reminders': <String>[],
      });

      await repository.updateBirthday('user-1', ref.id, draft());

      expect((await stored(ref.id)).containsKey('reminders'), isFalse);
    });

    test('are replaced by an update that sets them', () async {
      final ref = await seed({
        'uid': 'user-1',
        'name': 'Old',
        'date': Timestamp.fromDate(DateTime(1990)),
      });

      await repository.updateBirthday(
        'user-1',
        ref.id,
        draft(reminders: const {}),
      );

      expect((await stored(ref.id))['reminders'], isEmpty);
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

    test('clears the unknown year flag once the year is given', () async {
      final ref = await seed({
        'uid': 'user-1',
        'name': 'Mamie',
        'date': Timestamp.fromDate(DateTime(2000, 10, 15)),
        'yearKnown': false,
      });

      await repository.updateBirthday('user-1', ref.id, draft());

      final data = await stored(ref.id);
      expect(data['date'], Timestamp.fromDate(DateTime(1990, 5, 10)));
      expect(data['yearKnown'], true);
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

    test('keeps the years wished', () async {
      final ref = await seed({
        'uid': 'user-1',
        'name': 'Old',
        'date': Timestamp.fromDate(DateTime(1990)),
        'wishedYears': [2025],
      });

      await repository.updateBirthday('user-1', ref.id, draft());

      expect((await stored(ref.id))['wishedYears'], [2025]);
    });
  });

  group('markWished and unmarkWished', () {
    test('add a year once and leave the other fields alone', () async {
      final ref = await seed({
        'uid': 'user-1',
        'name': 'Alice',
        'date': Timestamp.fromDate(DateTime(1990)),
        'wishedYears': [2025],
      });

      await repository.markWished(ref.id, 2026);
      await repository.markWished(ref.id, 2026);

      final data = await stored(ref.id);
      expect(data['wishedYears'], [2025, 2026]);
      expect(data['uid'], 'user-1');
      expect(data['name'], 'Alice');
    });

    test('mark a document written before wishes', () async {
      final ref = await seed({
        'uid': 'user-1',
        'name': 'Alice',
        'date': Timestamp.fromDate(DateTime(1990)),
      });

      await repository.markWished(ref.id, 2026);

      expect((await stored(ref.id))['wishedYears'], [2026]);
    });

    test('remove only the year undone', () async {
      final ref = await seed({
        'uid': 'user-1',
        'name': 'Alice',
        'date': Timestamp.fromDate(DateTime(1990)),
        'wishedYears': [2025, 2026],
      });

      await repository.unmarkWished(ref.id, 2026);

      expect((await stored(ref.id))['wishedYears'], [2025]);
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

  group('removeCategory', () {
    test('drops the group from the given birthdays only', () async {
      Future<String> person(List<String> categories) async => (await seed({
        'uid': 'user-1',
        'name': 'P',
        'surname': '',
        'date': Timestamp.fromDate(DateTime(1990)),
        'categories': categories,
      })).id;
      final lea = await person(['book', 'family']);
      final tom = await person(['book']);
      final other = await person(['book']);

      await repository.removeCategory([lea, tom], 'book');

      expect((await stored(lea))['categories'], ['family']);
      expect((await stored(tom))['categories'], isEmpty);
      expect((await stored(other))['categories'], ['book']);
    });

    test('writes nothing for no birthday', () async {
      await repository.removeCategory(const [], 'book');

      expect((await firestore.collection('birthday').get()).docs, isEmpty);
    });
  });
}
