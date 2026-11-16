import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_backfill.dart';
import 'package:flutter_test/flutter_test.dart';

final _added = DateTime(2026, 11, 15, 10);

const _onePiece = Series(
  id: 'op',
  name: 'One Piece',
  keys: ['one piece'],
  complete: false,
);

Volume volume(
  String id, {
  String? seriesId = 'op',
  int? number,
  String? isbn,
  String? publisher,
  LookupState lookup = LookupState.found,
}) => Volume(
  id: id,
  seriesId: seriesId,
  number: number,
  isbn: isbn,
  title: '',
  authors: const [],
  publisher: publisher,
  lookup: lookup,
  addedAt: _added,
);

/// One Piece avec les tomes [numbers], scannés (id = ISBN fictif).
ShelfEntry entryOwning(List<int> numbers, {List<String?>? publishers}) =>
    shelfOf(
      [_onePiece],
      [
        for (final (index, number) in numbers.indexed)
          volume('v$number', number: number, publisher: publishers?[index]),
      ],
    ).entries.single;

BookMetadata record(
  String title, {
  String? publisher,
  String? isbn,
  String? seriesTitle,
  int? seriesNumber,
}) => BookMetadata(
  title: title,
  authors: const ['Eiichirō Oda'],
  publisher: publisher,
  isbn: isbn,
  seriesTitle: seriesTitle,
  seriesNumber: seriesNumber,
);

void main() {
  group('missingBefore', () {
    test('every number before it that the series lacks', () {
      expect(missingBefore(entryOwning([108]), 108), [
        for (var n = 1; n < 108; n++) n,
      ]);
      expect(missingBefore(entryOwning([1, 2, 5, 9]), 9), [3, 4, 6, 7, 8]);
    });

    test('only before the number, whatever comes after', () {
      expect(missingBefore(entryOwning([5, 10]), 5), [1, 2, 3, 4]);
    });

    test('nothing for volume 1, nor for a series without gaps', () {
      expect(missingBefore(entryOwning([1]), 1), isEmpty);
      expect(missingBefore(entryOwning([1, 2, 3]), 3), isEmpty);
    });
  });

  group('awaitsBackfill', () {
    test('a pending volume without ISBN, with its series and number', () {
      expect(
        awaitsBackfill(volume('a', number: 3, lookup: LookupState.pending)),
        isTrue,
      );
    });

    test('not a scanned volume, a found one, nor one to sort', () {
      expect(
        awaitsBackfill(
          volume('978', number: 3, isbn: '978', lookup: LookupState.pending),
        ),
        isFalse,
      );
      expect(awaitsBackfill(volume('a', number: 3)), isFalse);
      expect(
        awaitsBackfill(
          volume('a', seriesId: null, number: 3, lookup: LookupState.pending),
        ),
        isFalse,
      );
      expect(awaitsBackfill(volume('a', lookup: LookupState.pending)), isFalse);
    });
  });

  group('usualPublisherOf', () {
    test('the most frequent publisher of the series', () {
      expect(
        usualPublisherOf(
          entryOwning([1, 2, 3], publishers: ['Glénat', 'Kana', 'Glénat']),
        ),
        'Glénat',
      );
    });

    test('a tie goes to the highest number; none without publisher', () {
      expect(
        usualPublisherOf(entryOwning([1, 2], publishers: ['Kana', 'Glénat'])),
        'Glénat',
      );
      expect(
        usualPublisherOf(entryOwning([1, 2], publishers: [null, ' '])),
        isNull,
      );
    });
  });

  group('backfillRecordOf', () {
    final keys = {'one piece'};

    test('the record of that volume in that series', () {
      final wanted = record('One Piece - Tome 3', isbn: '9782723488525');
      expect(
        backfillRecordOf(keys, 3, [
          record('One Piece - Tome 30'),
          record('One Piece - Tome 3 : coffret'),
          wanted,
        ]),
        wanted,
      );
    });

    test('another edition, series or number is not taken', () {
      expect(
        backfillRecordOf(keys, 3, [
          record('One Piece - Perfect Edition - Tome 3'),
          record('Naruto - Tome 3'),
          record('One Piece - Tome 4'),
        ]),
        isNull,
      );
    });

    test('the structured series counts, and so does the title alone', () {
      final structured = record(
        'Le serment',
        seriesTitle: 'One Piece',
        seriesNumber: 3,
      );
      expect(backfillRecordOf(keys, 3, [structured]), structured);
      final titled = record(
        'One Piece - Tome 3',
        seriesTitle: 'Shonen One Piece',
      );
      expect(backfillRecordOf(keys, 3, [titled]), titled);
    });

    test('a volume numbered in its collection beats an art book', () {
      // L'art-book « One piece : color walk 1 », que la BnF rattache aussi
      // à One piece n° 1, sans que la collection de l'éditeur le numérote.
      const artBook = BookMetadata(
        title: 'One piece',
        subtitle: 'color walk',
        authors: [],
        publisher: 'Glénat',
        publishedDate: '2006',
        seriesTitle: 'One piece',
        seriesNumber: 1,
      );
      const volume = BookMetadata(
        title: 'Romance dawn',
        authors: [],
        publisher: 'Glénat',
        publishedDate: '2000',
        seriesTitle: 'One piece',
        seriesNumber: 1,
        numberedInCollection: true,
      );
      expect(
        backfillRecordOf(keys, 1, [artBook, volume], publisher: 'Glénat'),
        volume,
      );
    });

    test('no known publisher: the most frequent among the records', () {
      BookMetadata numbered(String publisher, String year) => BookMetadata(
        title: 'Tome 1',
        authors: const [],
        publisher: publisher,
        publishedDate: year,
        seriesTitle: 'One piece',
        seriesNumber: 1,
        numberedInCollection: true,
      );
      final novel = numbered('Hachette jeunesse', '2018');
      final manga = numbered('Glénat', '2013');
      expect(
        backfillRecordOf(keys, 1, [numbered('Glénat', '2000'), novel, manga]),
        manga,
      );
    });

    test('among equals, the latest printing', () {
      BookMetadata printing(String year) => BookMetadata(
        title: 'Romance dawn',
        authors: const [],
        publisher: 'Glénat',
        publishedDate: year,
        seriesTitle: 'One piece',
        seriesNumber: 1,
        numberedInCollection: true,
      );
      expect(
        backfillRecordOf(keys, 1, [
          printing('2000'),
          printing('impr. 2013'),
          printing('2005'),
        ]),
        printing('impr. 2013'),
      );
    });

    test('the usual publisher first, a near name included', () {
      final kana = record('One Piece - Tome 3', publisher: 'Kana');
      final glenat = record('One Piece - Tome 3', publisher: 'Glénat Manga');
      expect(
        backfillRecordOf(keys, 3, [kana, glenat], publisher: 'Glénat'),
        glenat,
      );
      expect(
        backfillRecordOf(keys, 3, [kana, glenat], publisher: 'Pika'),
        kana,
      );
      final editions = record(
        'One Piece - Tome 3',
        publisher: 'Éditions Glénat',
      );
      expect(
        backfillRecordOf(keys, 3, [kana, editions], publisher: 'Glénat'),
        editions,
      );
    });
  });

  group('backfilled', () {
    test('takes the record and keeps its place', () {
      final pending = volume('a', number: 3, lookup: LookupState.pending);
      final completed = backfilled(
        pending,
        const BookMetadata(
          title: 'One Piece',
          subtitle: 'Tome 3',
          authors: ['Eiichirō Oda'],
          publisher: 'Glénat',
          publishedDate: '2000-09',
          imageUrl: 'https://img/op3.jpg',
          isbn: '9782723488525',
        ),
      );

      expect(
        completed,
        Volume(
          id: 'a',
          seriesId: 'op',
          number: 3,
          isbn: '9782723488525',
          title: 'One Piece : Tome 3',
          authors: const ['Eiichirō Oda'],
          imageUrl: 'https://img/op3.jpg',
          publisher: 'Glénat',
          publishedDate: '2000-09',
          lookup: LookupState.found,
          addedAt: _added,
        ),
      );
    });

    test('without a record, complete as it is', () {
      final pending = volume('a', number: 3, lookup: LookupState.pending);
      final completed = backfilled(pending, null);

      expect(completed.lookup, LookupState.found);
      expect((completed.title, completed.isbn), ('', null));
      expect((completed.seriesId, completed.number), ('op', 3));
    });
  });

  group('replacedByScan', () {
    test('the volumes of that number that were not scanned', () {
      final volumes = [
        volume('by-hand', number: 3),
        volume('found-later', number: 3, isbn: '9782723488525'),
        volume('9782344059562', number: 3, isbn: '9782344059562'),
        volume('other-number', number: 4),
        volume('other-series', seriesId: 'naruto', number: 3),
      ];

      expect(
        replacedByScan(
          volumes,
          seriesId: 'op',
          number: 3,
          scannedId: '9782000000000',
        ),
        ['by-hand', 'found-later'],
      );
    });

    test('never the scanned volume itself', () {
      expect(
        replacedByScan(
          [volume('by-hand', number: 3)],
          seriesId: 'op',
          number: 3,
          scannedId: 'by-hand',
        ),
        isEmpty,
      );
    });
  });
}
