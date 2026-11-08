import 'package:an_ki/features/books/domain/volume_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseVolumeNumber', () {
    test('reads plain and prefixed numbers', () {
      const cases = {
        '15': 15,
        ' 7 ': 7,
        '03': 3,
        'T. 15': 15,
        'T15': 15,
        'Tome 3': 3,
        'tome12': 12,
        'Vol. 4': 4,
        'Volume 9': 9,
        'n° 4': 4,
        '#12': 12,
        '[15]': 15,
        '(8)': 8,
        '1000': 1000,
      };
      cases.forEach((text, number) {
        expect(parseVolumeNumber(text), number, reason: text);
      });
    });

    test('reads roman numerals', () {
      const cases = {'I': 1, 'IV': 4, 'ix': 9, 'XII': 12, 'Tome XIV': 14};
      cases.forEach((text, number) {
        expect(parseVolumeNumber(text), number, reason: text);
      });
    });

    test('rejects what is not one whole volume number', () {
      for (final text in [
        '',
        '0',
        '1001',
        '10.5',
        '10,5',
        '3-4',
        'hors-série',
        'abc',
        'IIII',
        'VX',
        'Tome',
        '12 bis',
      ]) {
        expect(parseVolumeNumber(text), isNull, reason: text);
      }
    });
  });

  group('parseRoman', () {
    test('reads canonical numerals up to 399', () {
      expect(parseRoman('XXXIX'), 39);
      expect(parseRoman('XLII'), 42);
      expect(parseRoman('xcix'), 99);
      expect(parseRoman('CCCXCIX'), 399);
    });

    test('rejects non-canonical forms and other letters', () {
      for (final text in ['', 'IIII', 'VV', 'IC', 'IL', 'ABC', 'MI', 'XIIII']) {
        expect(parseRoman(text), isNull, reason: text);
      }
    });
  });
}
