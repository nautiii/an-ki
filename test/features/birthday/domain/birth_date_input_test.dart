import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birth_date_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 12, 9);
  BirthDateInput parse(String text) => parseBirthDate(text, today);

  group('parseBirthDate', () {
    test('is empty for blank text', () {
      expect(parse(''), const BirthDateEmpty());
      expect(parse('   '), const BirthDateEmpty());
    });

    test('waits while the day or the month is unfinished', () {
      for (final text in ['0', '1', '12', '12/', '120', '12/0']) {
        expect(parse(text), const BirthDateIncomplete(), reason: text);
      }
    });

    test('reads a day and a month, the year left out', () {
      const march12 = BirthDateComplete(BirthDate(month: 3, day: 12));

      expect(parse('12/03'), march12);
      expect(parse('12/03/'), march12);
    });

    test('reads a full date', () {
      expect(
        parse('12/03/1990'),
        const BirthDateComplete(BirthDate(year: 1990, month: 3, day: 12)),
      );
    });

    test('tolerates digits alone, short parts and other separators', () {
      const march12 = BirthDateComplete(BirthDate(month: 3, day: 12));
      const march12In1990 = BirthDateComplete(
        BirthDate(year: 1990, month: 3, day: 12),
      );

      expect(parse('1203'), march12);
      expect(parse('12/3'), march12);
      expect(parse(' 12 - 3 '), march12);
      expect(parse('12031990'), march12In1990);
      expect(parse('12.03.1990'), march12In1990);
      expect(
        parse('1/3'),
        const BirthDateComplete(BirthDate(month: 3, day: 1)),
      );
    });

    test('accepts 29 February without a year or in a leap year', () {
      expect(
        parse('29/02'),
        const BirthDateComplete(BirthDate(month: 2, day: 29)),
      );
      expect(
        parse('29/02/2000'),
        const BirthDateComplete(BirthDate(year: 2000, month: 2, day: 29)),
      );
    });

    test('rejects a day that does not exist', () {
      for (final text in [
        '31/02',
        '31/04',
        '00/03',
        '0/3',
        '12/13',
        '12/00',
        '29/02/1990',
        '123/4',
        '120319901',
        '12/03/1990/1',
        'abc',
      ]) {
        expect(
          parse(text),
          const BirthDateInvalid(BirthDateError.noSuchDate),
          reason: text,
        );
      }
    });

    test('asks for the four digits of the year', () {
      for (final text in ['12/03/1', '12/03/199', '1203199']) {
        expect(
          parse(text),
          const BirthDateInvalid(BirthDateError.incompleteYear),
          reason: text,
        );
      }
    });

    test('rejects a date after today, today being fine', () {
      expect(
        parse('13/10/2026'),
        const BirthDateInvalid(BirthDateError.future),
      );
      expect(
        parse('12/10/2026'),
        const BirthDateComplete(BirthDate(year: 2026, month: 10, day: 12)),
      );
    });
  });

  group('maskBirthDateInput', () {
    test('adds a slash once the next part starts', () {
      expect(maskBirthDateInput('1'), '1');
      expect(maskBirthDateInput('12'), '12');
      expect(maskBirthDateInput('120'), '12/0');
      expect(maskBirthDateInput('1203'), '12/03');
      expect(maskBirthDateInput('12031'), '12/03/1');
      expect(maskBirthDateInput('12031990'), '12/03/1990');
    });

    test('keeps a typed separator, which closes the part', () {
      expect(maskBirthDateInput('12/'), '12/');
      expect(maskBirthDateInput('1/'), '1/');
      expect(maskBirthDateInput('1/3'), '1/3');
      expect(maskBirthDateInput('1/3/'), '1/3/');
      expect(maskBirthDateInput('12.03-1990'), '12/03/1990');
    });

    test('drops what cannot be part of a date', () {
      expect(maskBirthDateInput('/12'), '12');
      expect(maskBirthDateInput('1//3'), '1/3');
      expect(maskBirthDateInput('12a03'), '12/03');
      expect(maskBirthDateInput('120319901'), '12/03/1990');
      expect(maskBirthDateInput('12/03/1990/'), '12/03/1990');
    });
  });

  group('birthDateInputText', () {
    test('writes the day and month on two digits, then the year', () {
      expect(birthDateInputText(const BirthDate(month: 10, day: 5)), '05/10');
      expect(
        birthDateInputText(const BirthDate(year: 1990, month: 3, day: 12)),
        '12/03/1990',
      );
    });

    test('reads back as the same date', () {
      for (final date in const [
        BirthDate(month: 2, day: 29),
        BirthDate(year: 1990, month: 3, day: 12),
      ]) {
        expect(parse(birthDateInputText(date)), BirthDateComplete(date));
      }
    });
  });

  group('month first', () {
    BirthDateInput parseUs(String text) =>
        parseBirthDate(text, today, order: DayMonthOrder.monthFirst);

    test('reads the month, then the day, then the year', () {
      expect(
        parseUs('03/12'),
        const BirthDateComplete(BirthDate(month: 3, day: 12)),
      );
      expect(
        parseUs('1203'),
        const BirthDateComplete(BirthDate(month: 12, day: 3)),
      );
      expect(
        parseUs('03/12/1990'),
        const BirthDateComplete(BirthDate(year: 1990, month: 3, day: 12)),
      );
    });

    test('waits for the day after the month', () {
      for (final text in ['0', '03', '03/', '03/0']) {
        expect(parseUs(text), const BirthDateIncomplete(), reason: text);
      }
    });

    test('refuses a month or a day that does not exist', () {
      for (final text in ['13/01', '04/31', '02/29/1990']) {
        expect(
          parseUs(text),
          const BirthDateInvalid(BirthDateError.noSuchDate),
          reason: text,
        );
      }
    });

    test('writes the month first and reads it back', () {
      const date = BirthDate(year: 1990, month: 3, day: 12);

      expect(
        birthDateInputText(date, order: DayMonthOrder.monthFirst),
        '03/12/1990',
      );
      expect(
        parseUs(birthDateInputText(date, order: DayMonthOrder.monthFirst)),
        const BirthDateComplete(date),
      );
    });
  });

  group('DayMonthOrder.fromPattern', () {
    test('puts the month first when the short date does', () {
      expect(DayMonthOrder.fromPattern('M/d/y'), DayMonthOrder.monthFirst);
      expect(DayMonthOrder.fromPattern('y-MM-dd'), DayMonthOrder.monthFirst);
    });

    test('puts the day first otherwise', () {
      expect(DayMonthOrder.fromPattern('dd/MM/y'), DayMonthOrder.dayFirst);
      expect(DayMonthOrder.fromPattern('d.M.y'), DayMonthOrder.dayFirst);
      expect(DayMonthOrder.fromPattern(''), DayMonthOrder.dayFirst);
    });
  });
}
