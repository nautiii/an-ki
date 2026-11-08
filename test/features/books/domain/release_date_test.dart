import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tryParse', () {
    test('reads a day', () {
      final date = ReleaseDate.tryParse('2026-12-03');
      expect(date, const ReleaseDate(year: 2026, month: 12, day: 3));
      expect(date!.isMonthOnly, isFalse);
    });

    test('reads a month', () {
      final date = ReleaseDate.tryParse('2026-12');
      expect(date, const ReleaseDate(year: 2026, month: 12));
      expect(date!.isMonthOnly, isTrue);
    });

    test('accepts the last day of a month and a leap day', () {
      expect(ReleaseDate.tryParse('2026-04-30'), isNotNull);
      expect(ReleaseDate.tryParse('2028-02-29'), isNotNull);
    });

    test('rejects days and months that do not exist', () {
      for (final text in [
        '2026-02-30',
        '2027-02-29',
        '2026-04-31',
        '2026-13',
        '2026-00',
        '2026-12-00',
        '2026-12-32',
      ]) {
        expect(ReleaseDate.tryParse(text), isNull, reason: text);
      }
    });

    test('rejects other shapes', () {
      for (final text in [
        '',
        '2026',
        '12/2026',
        '2026-1-3',
        '2026-12-03T10:00',
        'décembre 2026',
      ]) {
        expect(ReleaseDate.tryParse(text), isNull, reason: text);
      }
    });

    test('ignores surrounding spaces', () {
      expect(
        ReleaseDate.tryParse(' 2026-12 '),
        const ReleaseDate(year: 2026, month: 12),
      );
    });
  });

  group('iso', () {
    test('round-trips with tryParse', () {
      for (final text in ['2026-12-03', '2026-12', '2026-01-01', '0999-05']) {
        expect(ReleaseDate.tryParse(text)!.iso, text);
      }
    });

    test('pads month and day', () {
      expect(const ReleaseDate(year: 2026, month: 3, day: 7).iso, '2026-03-07');
      expect(const ReleaseDate(year: 2026, month: 3).toString(), '2026-03');
    });
  });

  group('isOnOrAfter', () {
    final today = DateTime(2026, 11, 8);

    test('a day counts from today on, today included', () {
      expect(
        const ReleaseDate(year: 2026, month: 11, day: 8).isOnOrAfter(today),
        isTrue,
      );
      expect(
        const ReleaseDate(year: 2026, month: 11, day: 9).isOnOrAfter(today),
        isTrue,
      );
      expect(
        const ReleaseDate(year: 2026, month: 11, day: 7).isOnOrAfter(today),
        isFalse,
      );
    });

    test('a month counts until its end', () {
      expect(
        const ReleaseDate(year: 2026, month: 11).isOnOrAfter(today),
        isTrue,
      );
      expect(
        const ReleaseDate(
          year: 2026,
          month: 11,
        ).isOnOrAfter(DateTime(2026, 11, 30)),
        isTrue,
      );
      expect(
        const ReleaseDate(year: 2026, month: 10).isOnOrAfter(today),
        isFalse,
      );
      expect(
        const ReleaseDate(year: 2026, month: 12).isOnOrAfter(today),
        isTrue,
      );
    });

    test('compares the year first', () {
      expect(
        const ReleaseDate(year: 2027, month: 1, day: 1).isOnOrAfter(today),
        isTrue,
      );
      expect(
        const ReleaseDate(year: 2025, month: 12, day: 31).isOnOrAfter(today),
        isFalse,
      );
    });

    test('ignores the time of day', () {
      expect(
        const ReleaseDate(
          year: 2026,
          month: 11,
          day: 8,
        ).isOnOrAfter(DateTime(2026, 11, 8, 23, 59)),
        isTrue,
      );
    });
  });

  test('equality distinguishes day precision', () {
    const month = ReleaseDate(year: 2026, month: 12);
    const day = ReleaseDate(year: 2026, month: 12, day: 1);
    expect(month, isNot(day));
    expect(month.hashCode, const ReleaseDate(year: 2026, month: 12).hashCode);
  });
}
