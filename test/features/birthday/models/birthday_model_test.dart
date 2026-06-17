import 'package:an_ki/features/birthday/data/models/birthday_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  Future<QueryDocumentSnapshot<Map<String, dynamic>>> seed(
    Map<String, dynamic> data,
  ) async {
    await firestore.collection('birthday').add(data);
    final snapshot = await firestore.collection('birthday').get();
    return snapshot.docs.first;
  }

  group('BirthdayModel.fromFirestore', () {
    test('maps a complete document', () async {
      final doc = await seed({
        'uid': 'user-1',
        'name': 'Alice',
        'surname': 'Wonderland',
        'date': Timestamp.fromDate(DateTime(1990, 5, 10)),
        'categories': ['family', 'friend'],
        'picture': 'base64data',
      });

      final model = BirthdayModel.fromFirestore(doc);

      expect(model.id, doc.id);
      expect(model.uid, 'user-1');
      expect(model.name, 'Alice');
      expect(model.surname, 'Wonderland');
      expect(model.date, DateTime(1990, 5, 10));
      expect(model.categories, ['family', 'friend']);
      expect(model.picture, 'base64data');
    });

    test(
      'defaults categories to empty and picture to null when absent',
      () async {
        final doc = await seed({
          'uid': 'user-1',
          'name': 'Bob',
          'surname': 'Builder',
          'date': Timestamp.fromDate(DateTime(1985, 1, 1)),
        });

        final model = BirthdayModel.fromFirestore(doc);

        expect(model.categories, isEmpty);
        expect(model.picture, isNull);
      },
    );
  });

  group('BirthdayModel.toJson', () {
    test('serializes the date as a Timestamp and omits a null picture', () {
      final model = BirthdayModel(
        id: '1',
        uid: 'user-1',
        name: 'Alice',
        surname: 'Wonderland',
        date: DateTime(1990, 5, 10),
        categories: ['family'],
      );

      final json = model.toJson();

      expect(json['uid'], 'user-1');
      expect(json['name'], 'Alice');
      expect(json['surname'], 'Wonderland');
      expect(json['date'], Timestamp.fromDate(DateTime(1990, 5, 10)));
      expect(json['categories'], ['family']);
      expect(json.containsKey('picture'), isFalse);
    });

    test('includes the picture when present', () {
      final model = BirthdayModel(
        id: '1',
        uid: 'user-1',
        name: 'Alice',
        surname: 'Wonderland',
        date: DateTime(1990, 5, 10),
        categories: const [],
        picture: 'base64',
      );

      expect(model.toJson()['picture'], 'base64');
    });
  });

  group('BirthdayModel.copyWith', () {
    final base = BirthdayModel(
      id: '1',
      uid: 'user-1',
      name: 'Alice',
      surname: 'Wonderland',
      date: DateTime(1990, 5, 10),
      categories: const ['family'],
      picture: 'pic',
    );

    test('overrides only the provided fields', () {
      final copy = base.copyWith(name: 'Alicia', categories: ['friend']);

      expect(copy.name, 'Alicia');
      expect(copy.categories, ['friend']);
      expect(copy.id, base.id);
      expect(copy.uid, base.uid);
      expect(copy.surname, base.surname);
      expect(copy.date, base.date);
      expect(copy.picture, base.picture);
    });

    test('keeps every field when called with no argument', () {
      final copy = base.copyWith();

      expect(copy.id, base.id);
      expect(copy.uid, base.uid);
      expect(copy.name, base.name);
      expect(copy.surname, base.surname);
      expect(copy.date, base.date);
      expect(copy.categories, base.categories);
      expect(copy.picture, base.picture);
    });
  });
}
