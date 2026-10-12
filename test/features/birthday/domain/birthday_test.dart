import 'dart:typed_data';

import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Anniversaire de référence ; chaque argument en change un champ.
  Birthday birthday({
    List<String> categories = const ['family'],
    List<int> picture = const [1, 2, 3],
    DateTime? date,
  }) => Birthday(
    id: '1',
    name: 'Alice',
    surname: 'Wonderland',
    date: BirthDate.fromDate(date ?? DateTime(1990, 5, 10)),
    categories: categories,
    picture: Uint8List.fromList(picture),
  );

  group('equality', () {
    test('compares by value, categories and picture bytes included', () {
      final base = birthday();
      // Listes et octets distincts, de même contenu.
      final same = birthday(categories: ['family'], picture: [1, 2, 3]);

      expect(same, base);
      expect(same.hashCode, base.hashCode);
    });

    test('differs when a field differs', () {
      final base = birthday();

      expect(birthday(categories: ['friend']), isNot(base));
      expect(birthday(picture: [9]), isNot(base));
      expect(birthday(date: DateTime(1991, 5, 10)), isNot(base));
    });
  });
}
