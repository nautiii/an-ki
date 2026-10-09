import 'dart:typed_data';

import 'package:an_ki/features/birthday/domain/birthday_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = BirthdayModel(
    id: '1',
    name: 'Alice',
    surname: 'Wonderland',
    date: DateTime(1990, 5, 10),
    categories: const ['family'],
    picture: Uint8List.fromList([1, 2, 3]),
  );

  group('copyWith', () {
    test('overrides only the provided fields', () {
      final copy = base.copyWith(name: 'Alicia', categories: ['friend']);

      expect(copy.name, 'Alicia');
      expect(copy.categories, ['friend']);
      expect(copy.id, base.id);
      expect(copy.surname, base.surname);
      expect(copy.date, base.date);
      expect(copy.picture, base.picture);
    });

    test('keeps every field when called with no argument', () {
      expect(base.copyWith(), base);
    });

    test('removes the picture on request', () {
      expect(base.copyWith(clearPicture: true).picture, isNull);
    });
  });

  group('equality', () {
    test('compares by value, categories and picture bytes included', () {
      final same = base.copyWith(
        categories: ['family'],
        picture: Uint8List.fromList([1, 2, 3]),
      );

      expect(same, base);
      expect(same.hashCode, base.hashCode);
    });

    test('differs when a field differs', () {
      expect(base.copyWith(categories: ['friend']), isNot(base));
      expect(base.copyWith(picture: Uint8List.fromList([9])), isNot(base));
      expect(base.copyWith(date: DateTime(1991, 5, 10)), isNot(base));
    });
  });
}
