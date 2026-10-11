import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:flutter_test/flutter_test.dart';

Birthday _born(DateTime date, {String id = '1'}) =>
    Birthday(id: id, name: 'A', surname: 'B', date: date);

void main() {
  final today = DateTime(2026, 6, 15);

  group('nextOccurrence and daysUntilNext', () {
    test('are today and 0 on the birthday itself', () {
      final birthday = _born(DateTime(1990, 6, 15));

      expect(birthday.nextOccurrence(today), DateTime(2026, 6, 15));
      expect(birthday.daysUntilNext(today), 0);
    });

    test('stay in the current year for a birthday still ahead', () {
      final birthday = _born(DateTime(1990, 6, 20));

      expect(birthday.nextOccurrence(today), DateTime(2026, 6, 20));
      expect(birthday.daysUntilNext(today), 5);
    });

    test('roll over to next year once the birthday has passed', () {
      final birthday = _born(DateTime(1990, 6, 14));

      expect(birthday.nextOccurrence(today), DateTime(2027, 6, 14));
      expect(birthday.daysUntilNext(today), 364);
    });

    test('count calendar days across a daylight saving change', () {
      // Passage à l'heure d'été fin mars en Europe : 31 jours de calendrier,
      // mais une heure de moins entre les deux minuits locaux.
      final birthday = _born(DateTime(1990, 4));

      expect(birthday.daysUntilNext(DateTime(2026, 3)), 31);
    });

    test('ignore the time of day of today', () {
      final birthday = _born(DateTime(1990, 6, 16));

      expect(birthday.daysUntilNext(DateTime(2026, 6, 15, 23, 59)), 1);
    });

    test('move a 29 February birthday to 1 March in common years', () {
      final birthday = _born(DateTime(2000, 2, 29));

      expect(birthday.nextOccurrence(DateTime(2027, 2)), DateTime(2027, 3));
      expect(birthday.nextOccurrence(DateTime(2028, 2)), DateTime(2028, 2, 29));
    });
  });

  group('ageOn', () {
    test('counts the birthday from its day', () {
      expect(_born(DateTime(1990, 6, 15)).ageOn(today), 36);
    });

    test('is one less until the birthday of the year', () {
      expect(_born(DateTime(1990, 6, 16)).ageOn(today), 35);
      expect(_born(DateTime(1990, 12)).ageOn(today), 35);
    });

    test('is complete once the birthday has passed', () {
      expect(_born(DateTime(1990, 6, 14)).ageOn(today), 36);
      expect(_born(DateTime(1990)).ageOn(today), 36);
    });
  });

  group('sortedByNext', () {
    test('orders from the closest to the furthest birthday', () {
      final passed = _born(DateTime(1990, 6), id: 'passed');
      final soon = _born(DateTime(1990, 6, 20), id: 'soon');
      final todays = _born(DateTime(1990, 6, 15), id: 'today');

      final sorted = [passed, soon, todays].sortedByNext(today);

      expect(sorted.map((b) => b.id), ['today', 'soon', 'passed']);
    });
  });

  group('nextBirthdays', () {
    test('is empty for an empty list', () {
      expect(<Birthday>[].nextBirthdays(today), isEmpty);
    });

    test('returns the single closest birthday', () {
      final far = _born(DateTime(1990, 9), id: 'far');
      final close = _born(DateTime(1990, 6, 16), id: 'close');

      expect([far, close].nextBirthdays(today).map((b) => b.id), ['close']);
    });

    test('returns every birthday sharing the closest day', () {
      final a = _born(DateTime(1990, 6, 16), id: 'a');
      final b = _born(DateTime(1970, 6, 16), id: 'b');
      final later = _born(DateTime(1980, 6, 17), id: 'later');

      final next = [a, later, b].nextBirthdays(today);

      expect(next.map((b) => b.id), ['a', 'b']);
    });
  });
}
