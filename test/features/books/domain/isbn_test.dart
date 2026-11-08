import 'package:an_ki/features/books/domain/isbn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts the ISBN-13 of a book', () {
    expect(isBookIsbn('9780451524935'), isTrue);
    expect(isBookIsbn('9791032305690'), isTrue);
  });

  test('rejects any other code', () {
    expect(isBookIsbn('3017620422003'), isFalse); // produit
    expect(isBookIsbn('978045152493'), isFalse); // 12 chiffres
    expect(isBookIsbn('97804515249350'), isFalse); // 14 chiffres
    expect(isBookIsbn('978-0451524935'), isFalse);
    expect(isBookIsbn('https://example.com'), isFalse);
    expect(isBookIsbn(''), isFalse);
  });

  group('normalizeIsbn', () {
    test('keeps a valid ISBN-13', () {
      expect(normalizeIsbn('9782723492607'), '9782723492607');
    });

    test('strips hyphens, spaces and a label', () {
      for (final text in [
        '978-2-7234-9260-7',
        '978 2 7234 9260 7',
        ' 9782723492607 ',
        'ISBN 978-2-7234-9260-7',
        'isbn: 9782723492607',
        'ISBN-13: 978-2-7234-9260-7',
        'ISBN 13: 978-2-7234-9260-7',
        'ISBN13 9782723492607',
        '978–2–7234–9260–7', // demi-cadratins
      ]) {
        expect(normalizeIsbn(text), '9782723492607', reason: text);
      }
    });

    test('converts an ISBN-10 to ISBN-13', () {
      expect(normalizeIsbn('0451524934'), '9780451524935');
      expect(normalizeIsbn('0-451-52493-4'), '9780451524935');
      expect(normalizeIsbn('ISBN 0-451-52493-4'), '9780451524935');
    });

    test('reads the X check digit of an ISBN-10', () {
      expect(normalizeIsbn('080442957X'), '9780804429573');
      expect(normalizeIsbn('080442957x'), '9780804429573');
    });

    test('rejects a wrong check digit', () {
      expect(normalizeIsbn('9782723492608'), isNull);
      expect(normalizeIsbn('0451524935'), isNull);
      expect(normalizeIsbn('080442957X'.replaceFirst('X', '1')), isNull);
    });

    test('rejects a typo that swaps two digits', () {
      expect(normalizeIsbn('9782723492067'), isNull);
    });

    test('rejects what is not an ISBN', () {
      for (final text in [
        '',
        '   ',
        '9782723',
        '97827234926070', // 14 chiffres
        '3017620422003', // EAN de produit, clé valide
        'abcdefghijklm',
        '0451X24934', // X ailleurs qu'à la fin
        'https://example.com',
      ]) {
        expect(normalizeIsbn(text), isNull, reason: text);
      }
    });

    test('rejects an X inside the digits of an ISBN-10', () {
      expect(normalizeIsbn('04515X4934'), isNull);
    });
  });
}
