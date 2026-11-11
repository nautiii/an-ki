import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/release_check.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 11, 9);

NextVolumeInfo info({
  int number = 109,
  ReleaseStatus status = ReleaseStatus.unknown,
  ReleaseDate? date,
  ReleaseSource source = ReleaseSource.bnf,
  DateTime? checkedAt,
}) => NextVolumeInfo(
  number: number,
  status: status,
  date: date,
  source: source,
  checkedAt: checkedAt ?? DateTime(2026, 11),
);

/// Étagère d'une série [id] qui possède les tomes 1 à [ownedUpTo].
ShelfEntry entry({
  String id = 'op',
  String name = 'One Piece',
  List<String> keys = const ['one piece'],
  NextVolumeInfo? next,
  bool complete = false,
  int ownedUpTo = 108,
}) {
  final series = Series(
    id: id,
    name: name,
    keys: keys,
    complete: complete,
    next: next,
  );
  final volumes = [
    for (var n = 1; n <= ownedUpTo; n++)
      Volume(
        id: '$id$n',
        seriesId: id,
        number: n,
        title: 'T$n',
        authors: const [],
        lookup: LookupState.found,
        addedAt: DateTime(2026),
      ),
  ];
  return shelfOf([series], volumes).entries.single;
}

/// Notice de la BnF : série et numéro structurés, date d'édition.
BookMetadata record({
  String title = 'One Piece',
  String? series = 'One Piece',
  int? number = 109,
  String? publishedDate = '2026',
}) => BookMetadata(
  title: title,
  authors: const [],
  publishedDate: publishedDate,
  seriesTitle: series,
  seriesNumber: number,
);

void main() {
  group('needsReleaseCheck', () {
    test('a series nobody checked, or with stale info, is due', () {
      expect(needsReleaseCheck(entry(), now), isTrue);
      // L'information porte sur un tome désormais possédé.
      expect(
        needsReleaseCheck(
          entry(next: info(number: 108, source: ReleaseSource.user)),
          now,
        ),
        isTrue,
      );
    });

    test('a closed series, a date the user entered, a released volume: '
        'nothing to learn', () {
      expect(needsReleaseCheck(entry(complete: true), now), isFalse);
      expect(
        needsReleaseCheck(
          entry(
            next: info(
              source: ReleaseSource.user,
              status: ReleaseStatus.announced,
              date: const ReleaseDate(year: 2026, month: 12),
              checkedAt: DateTime(2025),
            ),
          ),
          now,
        ),
        isFalse,
      );
      expect(
        needsReleaseCheck(
          entry(
            next: info(
              status: ReleaseStatus.released,
              checkedAt: DateTime(2025),
            ),
          ),
          now,
        ),
        isFalse,
      );
      // Une date annoncée passée vaut « paru ».
      expect(
        needsReleaseCheck(
          entry(
            next: info(
              status: ReleaseStatus.announced,
              date: const ReleaseDate(year: 2026, month: 10, day: 2),
              checkedAt: DateTime(2025),
            ),
          ),
          now,
        ),
        isFalse,
      );
    });

    test('otherwise, once the last check is a week old', () {
      bool dueAfter(DateTime checkedAt) =>
          needsReleaseCheck(entry(next: info(checkedAt: checkedAt)), now);

      expect(dueAfter(now.subtract(const Duration(days: 7))), isTrue);
      expect(
        dueAfter(now.subtract(const Duration(days: 6, hours: 23))),
        isFalse,
      );
      // Une horloge en avance ne fait pas vérifier en boucle.
      expect(dueAfter(now.add(const Duration(days: 1))), isFalse);
      expect(
        needsReleaseCheck(
          entry(
            next: info(
              status: ReleaseStatus.announced,
              date: const ReleaseDate(year: 2026, month: 12, day: 3),
              checkedAt: DateTime(2026, 11, 2),
            ),
          ),
          now,
        ),
        isTrue,
      );
    });
  });

  group('entriesToCheck', () {
    test('never checked first, then the oldest check, within the limit', () {
      final fresh = entry(
        id: 'a',
        next: info(checkedAt: now),
      );
      final old = entry(
        id: 'b',
        next: info(checkedAt: DateTime(2026, 10)),
      );
      final older = entry(
        id: 'c',
        next: info(checkedAt: DateTime(2026, 9)),
      );
      final never = entry(id: 'd');
      final stale = entry(
        id: 'e',
        next: info(number: 100, checkedAt: DateTime(2026, 11, 10)),
      );

      final due = entriesToCheck([fresh, old, older, never, stale], now);

      expect(due.map((e) => e.series.id), ['d', 'e', 'c', 'b']);
      expect(
        entriesToCheck(
          [old, older, never],
          now,
          limit: 2,
        ).map((e) => e.series.id),
        ['d', 'c'],
      );
    });

    test('caps one opening at twenty series', () {
      final many = [for (var i = 0; i < 30; i++) entry(id: 's$i')];

      expect(entriesToCheck(many, now), hasLength(releaseChecksPerOpening));
      expect(releaseChecksPerOpening, 20);
    });
  });

  group('checkedRelease', () {
    test('a record of the volume with a year only: released', () {
      expect(
        checkedRelease(entry(), 109, [record()], now),
        NextVolumeInfo(
          number: 109,
          status: ReleaseStatus.released,
          source: ReleaseSource.bnf,
          checkedAt: now,
        ),
      );
    });

    test('a day to come (publisher metadata before release): announced', () {
      final result = checkedRelease(entry(), 109, [
        record(publishedDate: '2026-12-03'),
      ], now);

      expect(result!.status, ReleaseStatus.announced);
      expect(result.date, const ReleaseDate(year: 2026, month: 12, day: 3));
      expect(result.source, ReleaseSource.bnf);
    });

    test('a past day, or today: released, with its date', () {
      final past = checkedRelease(entry(), 109, [
        record(publishedDate: '2026-09-23'),
      ], now);
      final today = checkedRelease(entry(), 109, [
        record(publishedDate: '2026-11-11'),
      ], now);

      expect(past!.status, ReleaseStatus.released);
      expect(past.date, const ReleaseDate(year: 2026, month: 9, day: 23));
      expect(today!.status, ReleaseStatus.announced);
    });

    test('several records: the earliest dated one', () {
      final result = checkedRelease(entry(), 109, [
        record(),
        record(publishedDate: '2027-01-14'),
        record(publishedDate: '2026-12-03'),
        record(publishedDate: '2026-12'),
      ], now);

      expect(result!.date, const ReleaseDate(year: 2026, month: 12));
    });

    test('reads the title like a scan, « Édition originale » dropped', () {
      final result = checkedRelease(entry(), 109, [
        record(
          title: 'One Piece - Édition originale - Tome 109',
          series: 'Shonen One Piece',
          number: null,
        ),
      ], now);

      expect(result!.status, ReleaseStatus.released);
    });

    test('ignores another series, another number, a low-confidence guess', () {
      final result = checkedRelease(entry(), 109, [
        record(series: 'One Piece Party'),
        record(number: 1109),
        record(number: 110),
        // Repère en tête du titre : confiance basse.
        record(title: 'Tome 109 - One Piece', series: null, number: null),
      ], now);

      expect(result!.status, ReleaseStatus.unknown);
    });

    test('matches an old name of the series', () {
      final result = checkedRelease(
        entry(keys: const ['one piece', 'op']),
        109,
        [record(series: 'OP')],
        now,
      );

      expect(result!.status, ReleaseStatus.released);
    });

    test('no record: unknown, checked now', () {
      expect(
        checkedRelease(entry(), 109, const [], now),
        NextVolumeInfo(
          number: 109,
          status: ReleaseStatus.unknown,
          source: ReleaseSource.bnf,
          checkedAt: now,
        ),
      );
    });

    test('no record keeps what is known of the same volume', () {
      final entered = info(
        source: ReleaseSource.user,
        status: ReleaseStatus.announced,
        date: const ReleaseDate(year: 2026, month: 12, day: 3),
      );
      final seen = info(
        status: ReleaseStatus.announced,
        date: const ReleaseDate(year: 2026, month: 12, day: 3),
      );

      expect(checkedRelease(entry(next: entered), 109, const [], now), isNull);
      // Une notice vue avant reste, vérifiée maintenant : la série n'est plus
      // due à chaque ouverture.
      expect(
        checkedRelease(entry(next: seen), 109, const [], now),
        NextVolumeInfo(
          number: 109,
          status: ReleaseStatus.announced,
          date: const ReleaseDate(year: 2026, month: 12, day: 3),
          source: ReleaseSource.bnf,
          checkedAt: now,
        ),
      );
      // Une recherche vaine d'avant se met à jour.
      expect(
        checkedRelease(entry(next: info()), 109, const [], now)!.checkedAt,
        now,
      );
      // Un autre tome : ce qui était su est périmé.
      expect(
        checkedRelease(entry(next: seen), 110, const [], now)!.number,
        110,
      );
    });

    test('a dated record replaces a date the user entered', () {
      final entered = info(
        source: ReleaseSource.user,
        status: ReleaseStatus.announced,
        date: const ReleaseDate(year: 2026, month: 12, day: 3),
      );

      final result = checkedRelease(entry(next: entered), 109, [
        record(publishedDate: '2026-12-05'),
      ], now);

      expect(result!.source, ReleaseSource.bnf);
      expect(result.date, const ReleaseDate(year: 2026, month: 12, day: 5));
    });

    test('a record dated by its year only keeps a date the user entered', () {
      final entered = info(
        source: ReleaseSource.user,
        status: ReleaseStatus.announced,
        date: const ReleaseDate(year: 2026, month: 12, day: 3),
      );

      expect(
        checkedRelease(entry(next: entered), 109, [record()], now),
        isNull,
      );
    });

    test('a record of a year to come announces the volume, without date', () {
      expect(
        checkedRelease(entry(), 109, [record(publishedDate: 'DL 2027')], now),
        NextVolumeInfo(
          number: 109,
          status: ReleaseStatus.announced,
          source: ReleaseSource.bnf,
          checkedAt: now,
        ),
      );
      // Une seule notice de cette année : paru.
      expect(
        checkedRelease(entry(), 109, [
          record(publishedDate: '2027'),
          record(),
        ], now)!.status,
        ReleaseStatus.released,
      );
    });
  });

  group('enteredDateOf', () {
    test('the date the user entered for the next volume only', () {
      const date = ReleaseDate(year: 2026, month: 12);
      NextVolumeInfo next({
        int number = 109,
        ReleaseSource source = ReleaseSource.user,
      }) => info(
        number: number,
        source: source,
        status: ReleaseStatus.announced,
        date: date,
      );

      expect(enteredDateOf(entry(next: next())), date);
      expect(enteredDateOf(entry()), isNull);
      expect(
        enteredDateOf(entry(next: next(source: ReleaseSource.bnf))),
        isNull,
      );
      // Tome désormais possédé.
      expect(enteredDateOf(entry(next: next(number: 108))), isNull);
    });
  });

  group('enteredRelease', () {
    test('announced until the day, released after', () {
      final coming = enteredRelease(
        109,
        const ReleaseDate(year: 2026, month: 11),
        now,
      );
      final gone = enteredRelease(
        109,
        const ReleaseDate(year: 2026, month: 11, day: 10),
        now,
      );

      expect(
        coming,
        NextVolumeInfo(
          number: 109,
          status: ReleaseStatus.announced,
          date: const ReleaseDate(year: 2026, month: 11),
          source: ReleaseSource.user,
          checkedAt: now,
        ),
      );
      expect(gone.status, ReleaseStatus.released);
    });
  });
}
