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

  group('isBelated', () {
    test('is true the day after, for a birthday not wished', () {
      expect(_bornOn(10, 16).isBelated(DateTime(2026, 10, 17)), isTrue);
    });

    test('is false on the day itself and two days after', () {
      final birthday = _bornOn(10, 16);

      expect(birthday.isBelated(DateTime(2026, 10, 16)), isFalse);
      expect(birthday.isBelated(DateTime(2026, 10, 18)), isFalse);
    });

    test('is false once the birthday of yesterday was wished', () {
      final birthday = _bornOn(10, 16, wished: [2026]);

      expect(birthday.isBelated(DateTime(2026, 10, 17)), isFalse);
    });

    test('crosses the new year: a 31 December is wished for its year', () {
      final birthday = _bornOn(12, 31);

      expect(birthday.isBelated(DateTime(2027)), isTrue);
      expect(birthday.wishYear(DateTime(2027)), 2026);
      expect(
        _bornOn(12, 31, wished: [2026]).isBelated(DateTime(2027)),
        isFalse,
      );
    });

    test('follows the 1 March of a 29 February birthday', () {
      final leapling = _bornOn(2, 29);

      expect(leapling.isBelated(DateTime(2027, 3, 2)), isTrue);
      expect(leapling.isBelated(DateTime(2027, 3)), isFalse);
      expect(leapling.isBelated(DateTime(2028, 3)), isTrue);
    });

    test('ignores the hour of today', () {
      expect(_bornOn(10, 16).isBelated(DateTime(2026, 10, 17, 23, 59)), isTrue);
    });
  });

  test('belated keeps the people of yesterday still to wish, by name', () {
    Birthday person(
      String id,
      String name, {
      int day = 16,
      List<int> wished = const [],
    }) => Birthday(
      id: id,
      name: name,
      surname: '',
      date: BirthDate(month: 10, day: day),
      wishedYears: wished,
    );
    final birthdays = [
      person('zoe', 'Zoé'),
      person('today', 'Anna', day: 17),
      person('wished', 'Bea', wished: [2026]),
      person('leo-2', 'léo'),
      person('emile', 'Émile'),
      person('leo-1', 'Léo'),
    ];

    // Sans accents ni casse, puis par id entre homonymes.
    expect(birthdays.belated(DateTime(2026, 10, 17)).map((b) => b.id), [
      'emile',
      'leo-1',
      'leo-2',
      'zoe',
    ]);
  });
}
