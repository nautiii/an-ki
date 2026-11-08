import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_number.dart';
import 'package:flutter_test/flutter_test.dart';

Series series(String id, {bool complete = false, NextVolumeInfo? next}) =>
    Series(id: id, name: id, keys: [id], complete: complete, next: next);

Volume volume(
  String id, {
  String? seriesId,
  int? number,
  String? imageUrl,
  DateTime? addedAt,
}) => Volume(
  id: id,
  seriesId: seriesId,
  number: number,
  title: id,
  authors: const [],
  imageUrl: imageUrl,
  lookup: LookupState.found,
  addedAt: addedAt ?? DateTime(2026),
);

/// Tomes `numbers` de la série `seriesId`, un par numéro.
List<Volume> owning(String seriesId, Iterable<int> numbers) => [
  for (final n in numbers)
    volume('$seriesId-$n', seriesId: seriesId, number: n),
];

ShelfEntry entryOf(List<Series> all, List<Volume> volumes, String id) =>
    shelfOf(all, volumes).entries.singleWhere((e) => e.series.id == id);

void main() {
  group('shelfOf entries', () {
    test('1 to 12 and 15: last, holes and the first hole to buy', () {
      final entry = entryOf(
        [series('op')],
        owning('op', [...List.generate(12, (i) => i + 1), 15]),
        'op',
      );

      expect(entry.owned, [...List.generate(12, (i) => i + 1), 15]);
      expect(entry.last, 15);
      expect(entry.holes, [13, 14]);
      expect(entry.nextToBuy, 13);
    });

    test('no hole: the next one to buy is last + 1', () {
      final entry = entryOf([series('op')], owning('op', [1, 2, 3]), 'op');

      expect(entry.last, 3);
      expect(entry.holes, isEmpty);
      expect(entry.nextToBuy, 4);
    });

    test('a hole at the start counts', () {
      final entry = entryOf([series('op')], owning('op', [2, 3]), 'op');

      expect(entry.holes, [1]);
      expect(entry.nextToBuy, 1);
    });

    test('sorts owned numbers whatever the input order', () {
      final entry = entryOf([series('op')], owning('op', [5, 1, 3]), 'op');

      expect(entry.owned, [1, 3, 5]);
      expect(entry.volumes.map((v) => v.number), [1, 3, 5]);
      expect(entry.holes, [2, 4]);
    });

    test('a number owned twice appears once, both volumes are kept', () {
      final entry = entryOf(
        [series('op')],
        [
          volume('a', seriesId: 'op', number: 2, addedAt: DateTime(2026, 5)),
          volume('b', seriesId: 'op', number: 1),
          volume('c', seriesId: 'op', number: 2, addedAt: DateTime(2026, 2)),
        ],
        'op',
      );

      expect(entry.owned, [1, 2]);
      expect(entry.volumes.map((v) => v.id), ['b', 'c', 'a']);
      expect(entry.holes, isEmpty);
      expect(entry.nextToBuy, 3);
    });

    test('an empty series: nothing owned, start at 1', () {
      final entry = entryOf([series('op')], const [], 'op');

      expect(entry.owned, isEmpty);
      expect(entry.last, isNull);
      expect(entry.holes, isEmpty);
      expect(entry.nextToBuy, 1);
      expect(entry.coverUrl, isNull);
    });

    test('a complete series has nothing to buy but its holes', () {
      final all = [series('bs', complete: true)];

      expect(entryOf(all, owning('bs', [1, 2, 3]), 'bs').nextToBuy, isNull);
      expect(entryOf(all, owning('bs', [1, 3]), 'bs').nextToBuy, 2);
      expect(entryOf(all, const [], 'bs').nextToBuy, isNull);
    });

    test('keeps the order of the series and ignores other series volumes', () {
      final shelf = shelfOf(
        [series('b'), series('a')],
        [
          ...owning('a', [1]),
          ...owning('b', [1, 2]),
        ],
      );

      expect(shelf.entries.map((e) => e.series.id), ['b', 'a']);
      expect(shelf.entries[0].owned, [1, 2]);
      expect(shelf.entries[1].owned, [1]);
    });

    test('the largest allowed number still gives its holes', () {
      final entry = entryOf(
        [series('op')],
        owning('op', [maxVolumeNumber]),
        'op',
      );

      expect(entry.holes, hasLength(maxVolumeNumber - 1));
      expect(entry.nextToBuy, 1);
    });

    test('a number out of 1 to maxVolumeNumber is unclassified', () {
      for (final number in [0, -1, -3, maxVolumeNumber + 1, 2000000000]) {
        final shelf = shelfOf(
          [series('op')],
          [
            volume('bad', seriesId: 'op', number: number),
            ...owning('op', [1, 2]),
          ],
        );

        expect(shelf.unclassified.map((v) => v.id), ['bad'], reason: '$number');
        expect(shelf.entries.single.owned, [1, 2], reason: '$number');
        expect(shelf.entries.single.nextToBuy, 3, reason: '$number');
      }
    });
  });

  group('cover', () {
    test("is the last owned volume's", () {
      final entry = entryOf(
        [series('op')],
        [
          volume('1', seriesId: 'op', number: 1, imageUrl: 'https://c/1.jpg'),
          volume('3', seriesId: 'op', number: 3, imageUrl: 'https://c/3.jpg'),
          volume('2', seriesId: 'op', number: 2, imageUrl: 'https://c/2.jpg'),
        ],
        'op',
      );

      expect(entry.coverUrl, 'https://c/3.jpg');
    });

    test('falls back to the highest volume that has one', () {
      final entry = entryOf(
        [series('op')],
        [
          volume('1', seriesId: 'op', number: 1, imageUrl: 'https://c/1.jpg'),
          volume('2', seriesId: 'op', number: 2),
          volume('3', seriesId: 'op', number: 3, imageUrl: ''),
        ],
        'op',
      );

      expect(entry.coverUrl, 'https://c/1.jpg');
    });

    test('is null when no volume has one', () {
      final entry = entryOf([series('op')], owning('op', [1, 2]), 'op');

      expect(entry.coverUrl, isNull);
    });
  });

  group('unclassified', () {
    test(
      'gathers volumes without series, without number or of an unknown series',
      () {
        final shelf = shelfOf(
          [series('op')],
          [
            volume('loose'),
            volume('no-number', seriesId: 'op'),
            volume('orphan', seriesId: 'gone', number: 2),
            volume('number-only', number: 4),
            volume('ok', seriesId: 'op', number: 1),
          ],
        );

        expect(
          shelf.unclassified.map((v) => v.id),
          unorderedEquals(['loose', 'no-number', 'orphan', 'number-only']),
        );
        expect(shelf.entries.single.owned, [1]);
      },
    );

    test('lists the most recent first', () {
      final shelf = shelfOf(const [], [
        volume('old', addedAt: DateTime(2026)),
        volume('new', addedAt: DateTime(2026, 6)),
        volume('mid', addedAt: DateTime(2026, 3)),
      ]);

      expect(shelf.unclassified.map((v) => v.id), ['new', 'mid', 'old']);
    });

    test('an empty library gives an empty shelf', () {
      final shelf = shelfOf(const [], const []);

      expect(shelf.entries, isEmpty);
      expect(shelf.unclassified, isEmpty);
    });
  });

  test('does not modify its arguments', () {
    final volumes = owning('op', [3, 1, 2]);
    final copy = [...volumes];
    shelfOf([series('op')], volumes);

    expect(volumes, copy);
  });

  test('shelves compare by value', () {
    final a = shelfOf([series('op')], owning('op', [1, 2]));
    final b = shelfOf([series('op')], owning('op', [1, 2]));
    final c = shelfOf([series('op')], owning('op', [1, 3]));

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
    expect(a.entries.single, b.entries.single);
    expect(a.entries.single.hashCode, b.entries.single.hashCode);
    expect(a.entries.single, isNot(c.entries.single));
  });
}
