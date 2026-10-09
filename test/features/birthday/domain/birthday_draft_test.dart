import 'dart:typed_data';

import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = BirthdayDraft(
    name: 'Alice',
    surname: 'Wonderland',
    date: DateTime(1990, 5, 10),
    categories: const ['family'],
  );

  test('has no category and no picture by default', () {
    final draft = BirthdayDraft(name: 'A', surname: 'B', date: DateTime(2000));

    expect(draft.categories, isEmpty);
    expect(draft.picture, isNull);
  });

  group('copyWith', () {
    test('overrides only the provided fields', () {
      final picture = Uint8List.fromList([1, 2]);

      final copy = base.copyWith(
        name: 'Bob',
        categories: ['friend'],
        picture: picture,
      );

      expect(copy.name, 'Bob');
      expect(copy.categories, ['friend']);
      expect(copy.picture, picture);
      expect(copy.surname, base.surname);
      expect(copy.date, base.date);
    });

    test('keeps every field when called with no argument', () {
      expect(base.copyWith(), base);
    });

    test('removes the picture on request', () {
      final withPicture = base.copyWith(picture: Uint8List.fromList([1]));

      expect(withPicture.copyWith(clearPicture: true), base);
    });
  });

  test('equality compares by value', () {
    final same = base.copyWith(categories: ['family']);

    expect(same, base);
    expect(same.hashCode, base.hashCode);
    expect(base.copyWith(surname: 'Other'), isNot(base));
  });
}
