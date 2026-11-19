import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birth_date_input.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/domain/quick_birthday.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 15, 9);
  QuickBirthday read(
    String line, {
    DayMonthOrder order = DayMonthOrder.dayFirst,
  }) => readQuickBirthday(line, today, order: order);

  QuickBirthday person(String name, int month, int day, [int? year]) =>
      QuickBirthday(
        fullName: name,
        date: BirthDateComplete(BirthDate(year: year, month: month, day: day)),
      );

  group('readQuickBirthday', () {
    test('is empty for a blank line', () {
      expect(
        read(''),
        const QuickBirthday(fullName: '', date: BirthDateEmpty()),
      );
      expect(read('   '), read(''));
    });

    test('reads the name then the date in digits', () {
      expect(read('Léa 12/03'), person('Léa', 3, 12));
      expect(
        read('Hugo Bernard 17/11/1990'),
        person('Hugo Bernard', 11, 17, 1990),
      );
      expect(read('Léa 1203'), person('Léa', 3, 12));
      expect(read('Léa 12.03.1990'), person('Léa', 3, 12, 1990));
    });

    test('reads the date before the name', () {
      expect(read('12/03 Zoé'), person('Zoé', 3, 12));
      expect(read('12 mars Zoé'), person('Zoé', 3, 12));
      expect(read('March 12, 1990 Tom'), person('Tom', 3, 12, 1990));
    });

    test('reads months in words, French and English, full or short', () {
      final cases = {
        'Léa 12 mars': person('Léa', 3, 12),
        'Léa 12 MARS': person('Léa', 3, 12),
        'Léa 3 févr.': person('Léa', 2, 3),
        'Léa 3 fevrier': person('Léa', 2, 3),
        'Léa 15 août': person('Léa', 8, 15),
        'Léa 15 aout 1980': person('Léa', 8, 15, 1980),
        'Léa 1er janvier': person('Léa', 1, 1),
        'Léa 2 sept': person('Léa', 9, 2),
        'Léa 24 déc': person('Léa', 12, 24),
        'Tom March 12': person('Tom', 3, 12),
        'Tom Dec 3, 1975': person('Tom', 12, 3, 1975),
        'Tom 4th July': person('Tom', 7, 4),
        'Hugo Bernard 17 novembre 1990': person('Hugo Bernard', 11, 17, 1990),
      };
      for (final MapEntry(key: line, value: expected) in cases.entries) {
        expect(read(line), expected, reason: line);
      }
    });

    test('follows the region order for digits only', () {
      expect(
        read('Tom 03/12', order: DayMonthOrder.monthFirst),
        person('Tom', 3, 12),
      );
      expect(
        read('Tom 3/12/1990', order: DayMonthOrder.monthFirst),
        person('Tom', 3, 12, 1990),
      );
      // Un mois en toutes lettres n'a pas d'ordre à deviner.
      expect(
        read('Tom 12 mars', order: DayMonthOrder.monthFirst),
        person('Tom', 3, 12),
      );
    });

    test('completes a two-digit year with the latest past century', () {
      expect(read('Mamie 3/2/50'), person('Mamie', 2, 3, 1950));
      expect(read('Noé 3/2/12'), person('Noé', 2, 3, 2012));
      expect(read('Léa 12 mars 90'), person('Léa', 3, 12, 1990));
      // Le 3 décembre 2026 est à venir : 1926.
      expect(read('Papi 3/12/26'), person('Papi', 12, 3, 1926));
      expect(read('Léa 120350'), person('Léa', 3, 12, 1950));
    });

    test('drops the words that link the name to the date', () {
      expect(read('Léa le 12 mars'), person('Léa', 3, 12));
      expect(read('Léa, née le 12 mars'), person('Léa', 3, 12));
      expect(read('Tom born on March 12'), person('Tom', 3, 12));
      expect(read('12 mars : Léa'), person('Léa', 3, 12));
    });

    test('keeps a surname that looks like a link word', () {
      expect(read('Anh Lê 3 mai'), person('Anh Lê', 5, 3));
      expect(read('Hoa Le 3 mai'), person('Hoa Le', 5, 3));
      // Les majuscules du clavier n'en font pas un nom.
      expect(read('Léa Née Le 12 Mars'), person('Léa', 3, 12));
      expect(read('Tom Born On March 12'), person('Tom', 3, 12));
    });

    test('keeps the line as typed', () {
      expect(read('  31/13  ').source, '31/13');
      expect(read('Léa   12 mars').source, 'Léa 12 mars');
    });

    test('keeps a month name as a first name away from a day', () {
      expect(
        read('Avril Lavigne 27 septembre'),
        person('Avril Lavigne', 9, 27),
      );
      expect(read('Mai 12 mars'), person('Mai', 3, 12));
      expect(read('Avril 12/05'), person('Avril', 5, 12));
    });

    test('has no date when none is written', () {
      expect(
        read('Léa Martin'),
        const QuickBirthday(fullName: 'Léa Martin', date: BirthDateEmpty()),
      );
    });

    test('has no name when only a date is written', () {
      expect(read('12 mars'), person('', 3, 12));
      expect(read('12/03'), person('', 3, 12));
      expect(read('12 mars').isReady, isFalse);
    });

    test('waits while the date is being typed', () {
      for (final line in [
        'Léa 1',
        'Léa 12',
        'Léa 12/0',
        'Léa 12 m',
        'Léa 12 nov',
      ]) {
        final reading = read(line);
        expect(reading.fullName, 'Léa', reason: line);
        expect(
          reading.date,
          line == 'Léa 12 nov'
              ? const BirthDateComplete(BirthDate(month: 11, day: 12))
              : const BirthDateIncomplete(),
          reason: line,
        );
      }
      expect(
        read('Léa 12 mars 199').date,
        const BirthDateInvalid(BirthDateError.incompleteYear),
      );
      expect(
        read('Léa 12/03/199').date,
        const BirthDateInvalid(BirthDateError.incompleteYear),
      );
    });

    test('says why a date does not exist', () {
      expect(
        read('Léa 31/04').date,
        const BirthDateInvalid(BirthDateError.noSuchDate),
      );
      expect(
        read('Léa 31 avril').date,
        const BirthDateInvalid(BirthDateError.noSuchDate),
      );
      expect(
        read('Léa 29 février 1990').date,
        const BirthDateInvalid(BirthDateError.noSuchDate),
      );
      expect(
        read('Léa 12 mars 2030').date,
        const BirthDateInvalid(BirthDateError.future),
      );
    });

    test('accepts the 29th of February without a year', () {
      expect(read('Léa 29 février'), person('Léa', 2, 29));
    });
  });

  group('QuickBirthday.draft', () {
    test('splits the name and carries groups and photo', () {
      final draft = read('Hugo Bernard 17 novembre 1990')
          .draft(categories: ['friend']);
      expect(
        draft,
        const BirthdayDraft(
          name: 'Hugo',
          surname: 'Bernard',
          date: BirthDate(year: 1990, month: 11, day: 17),
          categories: ['friend'],
        ),
      );
    });

    test('is null until the line is ready', () {
      expect(read('Léa').draft(), isNull);
      expect(read('12 mars').draft(), isNull);
      expect(read('Léa 31/04').draft(), isNull);
    });
  });

  group('readQuickBirthdays', () {
    test('reads each non-blank line', () {
      expect(readQuickBirthdays('Léa 12 mars\n\n  \n12/03 Zoé', today), [
        person('Léa', 3, 12),
        person('Zoé', 3, 12),
      ]);
    });
  });

  group('previewQuickBatch', () {
    Birthday existing(String name, String surname, int month, int day) =>
        Birthday(
          id: name,
          name: name,
          surname: surname,
          date: BirthDate(month: month, day: day),
        );

    test('keeps new people in line order, once each', () {
      final batch = previewQuickBatch(
        readQuickBirthdays(
          'Zoé 1/1\nLéa Martin 12 mars\nleá martin 12/03/1990\nHugo 3/3',
          today,
        ),
        existing: [existing('Hugo', '', 3, 3)],
      );

      expect(batch.fresh, [person('Zoé', 1, 1), person('Léa Martin', 3, 12)]);
      expect(batch.known, [
        person('leá martin', 3, 12, 1990),
        person('Hugo', 3, 3),
      ]);
      expect(batch.unreadable, isEmpty);
    });

    test('sets aside lines without a name or a full date', () {
      final batch = previewQuickBatch(
        readQuickBirthdays('Tonton Paul\n12 mars\nLéa 31/04\nZoé 2/2', today),
        existing: const [],
      );

      expect(batch.fresh, [person('Zoé', 2, 2)]);
      expect(
        [for (final line in batch.unreadable) line.fullName],
        ['Tonton Paul', '', 'Léa'],
      );
    });
  });

  group('isKnownBirthday', () {
    const hugo = Birthday(
      id: '1',
      name: 'Hugo',
      surname: 'Bernard',
      date: BirthDate(year: 1990, month: 11, day: 17),
    );

    test('matches the name and the day, whatever the year', () {
      expect(isKnownBirthday(read('hugo bernard 17/11'), [hugo]), isTrue);
      expect(isKnownBirthday(read('Hugo Bernard 18/11'), [hugo]), isFalse);
      expect(isKnownBirthday(read('Hugo 17/11'), [hugo]), isFalse);
    });

    test('is false for a line that is not ready', () {
      expect(isKnownBirthday(read('Hugo Bernard'), [hugo]), isFalse);
    });
  });
}
