import 'package:an_ki/features/book_scanner/domain/book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Livre de référence ; chaque argument en change un champ.
  Book book({List<String> authors = const ['A'], DateTime? scannedAt}) => Book(
    id: '1',
    title: 'T',
    authors: authors,
    isbn: '1',
    pageCount: 100,
    scannedAt: scannedAt,
  );

  group('equality', () {
    test('compares by value, authors included', () {
      final base = book();
      // Liste distincte, de même contenu.
      final same = book(authors: ['A']);

      expect(same, base);
      expect(same.hashCode, base.hashCode);
    });

    test('differs when a field differs', () {
      final base = book();

      expect(book(authors: ['B']), isNot(base));
      expect(book(scannedAt: DateTime(2024)), isNot(base));
    });
  });
}
