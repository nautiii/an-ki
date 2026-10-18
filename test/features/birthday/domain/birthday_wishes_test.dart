import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Né le [day]/[month] (année inconnue), souhaité les années [wished].
Birthday _bornOn(int month, int day, {List<int> wished = const []}) => Birthday(
  id: '1',
  name: 'Léa',
  surname: 'Martin',
  date: BirthDate(month: month, day: day),
  wishedYears: wished,
);

void main() {
  group('wishYear', () {
    test('is the current year on the birthday itself', () {
      expect(_bornOn(10, 16).wishYear(DateTime(2026, 10, 16)), 2026);
    });

    test('stays on this year once the birthday has passed', () {
      expect(_bornOn(10, 16).wishYear(DateTime(2026, 10, 20)), 2026);
    });

    test('goes back a year before the birthday comes round again', () {
      // Le 31 décembre, souhaité en retard le 1er janvier.
      expect(_bornOn(12, 31).wishYear(DateTime(2027)), 2026);
    });
  });

  group('isWished', () {
    test('is true when the birthday of this year was wished', () {
      final birthday = _bornOn(10, 16, wished: [2025, 2026]);

      expect(birthday.isWished(DateTime(2026, 10, 16)), isTrue);
    });

    test('is false when only past years were wished', () {
      final birthday = _bornOn(10, 16, wished: [2024, 2025]);

      expect(birthday.isWished(DateTime(2026, 10, 16)), isFalse);
    });

    test('is false for a birthday never wished', () {
      expect(_bornOn(10, 16).isWished(DateTime(2026, 10, 16)), isFalse);
    });

    test('follows the 1 March of a 29 February birthday', () {
      final leapling = _bornOn(2, 29, wished: [2027]);

      expect(leapling.isWished(DateTime(2027, 3)), isTrue);
      expect(leapling.isWished(DateTime(2027, 2, 28)), isFalse);
    });
  });
}
