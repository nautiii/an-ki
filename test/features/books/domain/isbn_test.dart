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
}
