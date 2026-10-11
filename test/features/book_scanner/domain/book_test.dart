import 'package:an_ki/features/book_scanner/domain/book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = Book(
    id: '1',
    title: 'T',
    authors: ['A'],
    isbn: '1',
    pageCount: 100,
  );

  test('copyWith overrides selected fields and keeps the rest', () {
    final scannedAt = DateTime(2024);

    final copy = base.copyWith(title: 'T2', scannedAt: scannedAt);

    expect(copy.title, 'T2');
    expect(copy.scannedAt, scannedAt);
    expect(copy.id, '1');
    expect(copy.isbn, '1');
    expect(copy.authors, ['A']);
    expect(copy.pageCount, 100);
    expect(base.copyWith(), base);
  });

  group('equality', () {
    test('compares by value, authors included', () {
      final same = base.copyWith(authors: ['A']);

      expect(same, base);
      expect(same.hashCode, base.hashCode);
    });

    test('differs when a field differs', () {
      expect(base.copyWith(authors: ['B']), isNot(base));
      expect(base.copyWith(scannedAt: DateTime(2024)), isNot(base));
    });
  });
}
