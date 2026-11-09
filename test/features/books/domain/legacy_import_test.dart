import 'package:an_ki/features/books/domain/legacy_import.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 8);

LegacyBook _book(
  String id,
  String title, {
  String isbn = '9782344059562',
  DateTime? scannedAt,
  String? imageUrl,
  List<String> authors = const [],
}) => LegacyBook(
  id: id,
  title: title,
  authors: authors,
  isbn: isbn,
  imageUrl: imageUrl,
  scannedAt: scannedAt,
);

void main() {
  var ids = 0;
  String newId() => 'new${ids++}';

  setUp(() => ids = 0);

  LegacyImportPlan plan(
    List<LegacyBook> books, {
    List<Series> series = const [],
    Set<String> owned = const {},
  }) => planLegacyImport(
    books: books,
    series: series,
    ownedVolumeIds: owned,
    now: _now,
    newSeriesId: newId,
  );

  test('nothing to import gives an empty plan', () {
    expect(plan(const []).isEmpty, isTrue);
  });

  test('a recognised title creates its series once', () {
    final result = plan([
      _book('k1', 'One Piece - Tome 1', isbn: '9782723488525'),
      _book('k2', 'One piece T2', isbn: '9782723489898'),
    ]);

    expect(result.entries, hasLength(2));
    final [first, second] = result.entries;
    expect(
      first.newSeries,
      const Series(
        id: 'new0',
        name: 'One Piece',
        keys: ['one piece'],
        complete: false,
      ),
    );
    expect(second.newSeries, isNull);
    expect((first.volume?.seriesId, first.volume?.number), ('new0', 1));
    expect((second.volume?.seriesId, second.volume?.number), ('new0', 2));
  });

  test('joins an existing series by its key', () {
    const existing = Series(
      id: 's1',
      name: 'One Piece',
      keys: ['one piece'],
      complete: false,
    );

    final entry = plan(
      [_book('k1', 'ONE PIECE - Tome 108')],
      series: [existing],
    ).entries.single;

    expect(entry.newSeries, isNull);
    expect((entry.volume?.seriesId, entry.volume?.number), ('s1', 108));
  });

  test('an unrecognised title stays unclassified, as found', () {
    final scanned = DateTime(2025, 3, 2);

    final entry = plan([
      _book(
        'k1',
        'Dune',
        isbn: '978-0-441-17271-9',
        scannedAt: scanned,
        authors: ['Frank Herbert'],
        imageUrl: 'https://img/dune.jpg',
      ),
    ]).entries.single;

    expect(
      entry.volume,
      Volume(
        id: '9780441172719',
        isbn: '9780441172719',
        title: 'Dune',
        authors: const ['Frank Herbert'],
        imageUrl: 'https://img/dune.jpg',
        lookup: LookupState.found,
        addedAt: scanned,
      ),
    );
    expect(entry.legacyBookIds, ['k1']);
  });

  test('merges duplicate ISBNs, the oldest scan first', () {
    final entry = plan([
      _book(
        'late',
        'Dune',
        scannedAt: DateTime(2026),
        imageUrl: 'https://img/late.jpg',
        authors: ['Frank Herbert'],
      ),
      _book('early', '', scannedAt: DateTime(2025)),
    ]).entries.single;

    expect(entry.legacyBookIds, ['early', 'late']);
    expect(entry.volume?.addedAt, DateTime(2025));
    expect(entry.volume?.title, 'Dune');
    expect(entry.volume?.authors, ['Frank Herbert']);
    expect(entry.volume?.imageUrl, 'https://img/late.jpg');
  });

  test('a volume already on the shelf is only marked', () {
    final entry = plan(
      [_book('k1', 'One Piece - Tome 108')],
      owned: {'9782344059562'},
    ).entries.single;

    expect(entry.volume, isNull);
    expect(entry.newSeries, isNull);
    expect(entry.legacyBookIds, ['k1']);
    expect(ids, 0);
  });

  test('an unreadable ISBN keeps the legacy id, dated now', () {
    final entry = plan([_book('k1', 'Sans code', isbn: '123')]).entries.single;

    expect(entry.volume?.id, 'k1');
    expect(entry.volume?.isbn, isNull);
    expect(entry.volume?.addedAt, _now);
  });
}
