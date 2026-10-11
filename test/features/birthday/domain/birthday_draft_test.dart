import 'dart:typed_data';

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
    date: DateTime(1990, 5, 10),
    categories: categories,
    picture: picture == null ? null : Uint8List.fromList(picture),
  );

  test('has no category and no picture by default', () {
    final draft = BirthdayDraft(name: 'A', surname: 'B', date: DateTime(2000));

    expect(draft.categories, isEmpty);
    expect(draft.picture, isNull);
  });

  group('validation', () {
    test('a name needs more than spaces', () {
      expect(BirthdayDraft.isValidName('Alice'), isTrue);
      expect(BirthdayDraft.isValidName(' Al '), isTrue);
      expect(BirthdayDraft.isValidName(''), isFalse);
      expect(BirthdayDraft.isValidName('   '), isFalse);
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
