import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_search.dart';
import 'package:flutter_test/flutter_test.dart';

ShelfEntry _entry(String id, String name) => shelfOf([
  Series(id: id, name: name, keys: const [], complete: false),
], const []).entries.single;

List<String> _names(List<ShelfEntry> entries) => [
  for (final entry in entries) entry.series.name,
];

void main() {
  final entries = [
    _entry('1', 'One Piece'),
    _entry('2', 'blacksad'),
    _entry('3', 'Éclat'),
    _entry('4', 'Astérix'),
  ];

  group('searchShelf', () {
    test('sorts A to Z ignoring case and accents', () {
      expect(_names(searchShelf(entries, '')), [
        'Astérix',
        'blacksad',
        'Éclat',
        'One Piece',
      ]);
    });

    test('a blank query returns every series', () {
      expect(searchShelf(entries, '   '), hasLength(4));
    });

    test('filters on a folded substring', () {
      expect(_names(searchShelf(entries, 'pi')), ['One Piece']);
      expect(_names(searchShelf(entries, 'ASTE')), ['Astérix']);
      expect(_names(searchShelf(entries, 'eclat')), ['Éclat']);
    });

    test('finds nothing for an unknown name', () {
      expect(searchShelf(entries, 'zzz'), isEmpty);
    });

    test('two series with the exact same name keep an order by id', () {
      final twins = [_entry('b', 'Naruto'), _entry('a', 'Naruto')];

      expect([for (final e in searchShelf(twins, '')) e.series.id], ['a', 'b']);
      expect(
        [for (final e in searchShelf(twins.reversed.toList(), '')) e.series.id],
        ['a', 'b'],
      );
    });

    test('ties on the folded name fall back on the raw name', () {
      final tied = [_entry('1', 'eclat'), _entry('2', 'Eclat')];

      expect(_names(searchShelf(tied, '')), ['Eclat', 'eclat']);
      expect(_names(searchShelf(tied.reversed.toList(), '')), [
        'Eclat',
        'eclat',
      ]);
    });
  });
}
