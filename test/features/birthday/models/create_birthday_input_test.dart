import 'package:an_ki/features/birthday/data/models/create_birthday_input.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  group('CreateBirthdayInput.toJson', () {
    test('trims name and surname and serializes the date', () {
      final input = CreateBirthdayInput(
        uid: 'user-1',
        name: '  Alice  ',
        surname: '  Wonderland ',
        date: DateTime(1990, 5, 10),
        categories: const ['family'],
      );

      final json = input.toJson();

      expect(json['uid'], 'user-1');
      expect(json['name'], 'Alice');
      expect(json['surname'], 'Wonderland');
      expect(json['date'], Timestamp.fromDate(DateTime(1990, 5, 10)));
      expect(json['categories'], ['family']);
      // The picture file is never serialized here (handled by the repository).
      expect(json.containsKey('picture'), isFalse);
    });
  });

  group('CreateBirthdayInput.copyWith', () {
    final base = CreateBirthdayInput(
      uid: 'user-1',
      name: 'Alice',
      surname: 'Wonderland',
      date: DateTime(1990, 5, 10),
      categories: const ['family'],
    );

    test('overrides only the provided fields', () {
      final picture = XFile('path/to/pic.jpg');
      final copy = base.copyWith(
        name: 'Bob',
        categories: const ['friend'],
        pictureFile: picture,
      );

      expect(copy.name, 'Bob');
      expect(copy.categories, const ['friend']);
      expect(copy.pictureFile, picture);
      expect(copy.uid, base.uid);
      expect(copy.surname, base.surname);
      expect(copy.date, base.date);
    });

    test('keeps every field when called with no argument', () {
      final copy = base.copyWith();

      expect(copy.uid, base.uid);
      expect(copy.name, base.name);
      expect(copy.surname, base.surname);
      expect(copy.date, base.date);
      expect(copy.categories, base.categories);
      expect(copy.pictureFile, isNull);
    });
  });
}
