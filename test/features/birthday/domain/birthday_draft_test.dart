import 'dart:typed_data';

import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Brouillon de référence ; chaque argument en change un champ.
  BirthdayDraft draft({
    String surname = 'Wonderland',
    List<String> categories = const ['family'],
    List<int>? picture,
  }) => BirthdayDraft(
    name: 'Alice',
    surname: surname,
    date: BirthDate.fromDate(DateTime(1990, 5, 10)),
    categories: categories,
    picture: picture == null ? null : Uint8List.fromList(picture),
  );

  test('has no category and no picture by default', () {
    final draft = BirthdayDraft(
      name: 'A',
      surname: 'B',
      date: BirthDate.fromDate(DateTime(2000)),
    );

    expect(draft.categories, isEmpty);
    expect(draft.picture, isNull);
  });

  test('fullName joins the names without a stray space', () {
    expect(draft().fullName, 'Alice Wonderland');
    expect(draft(surname: '').fullName, 'Alice');
    expect(draft(surname: '  ').fullName, 'Alice');
  });

  group('validation', () {
    test('a name needs more than spaces', () {
      expect(BirthdayDraft.isValidName('Alice'), isTrue);
      expect(BirthdayDraft.isValidName(' Al '), isTrue);
      expect(BirthdayDraft.isValidName(''), isFalse);
      expect(BirthdayDraft.isValidName('   '), isFalse);
    });
  });

  group('splitFullName', () {
    test('takes the first word as first name, the rest as last name', () {
      expect(BirthdayDraft.splitFullName('Léa Martin'), (
        name: 'Léa',
        surname: 'Martin',
      ));
      expect(BirthdayDraft.splitFullName('  Jean  Pierre   Dupont '), (
        name: 'Jean',
        surname: 'Pierre Dupont',
      ));
    });

    test('leaves the last name empty for a single word', () {
      expect(BirthdayDraft.splitFullName('Mamie'), (
        name: 'Mamie',
        surname: '',
      ));
    });
  });

  test('equality compares by value, picture bytes included', () {
    final base = draft(picture: [1]);
    // Listes et octets distincts, de même contenu.
    final same = draft(categories: ['family'], picture: [1]);

    expect(same, base);
    expect(same.hashCode, base.hashCode);
    expect(draft(surname: 'Other', picture: [1]), isNot(base));
    expect(draft(), isNot(base));
  });
}
