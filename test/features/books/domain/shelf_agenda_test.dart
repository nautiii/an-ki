import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_agenda.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 11, 24);

NextVolumeInfo info(
  int number, {
  ReleaseStatus status = ReleaseStatus.announced,
  ReleaseDate? date,
}) => NextVolumeInfo(
  number: number,
  status: status,
  date: date,
  source: ReleaseSource.bnf,
  checkedAt: DateTime(2026, 11),
);

/// Une série nommée [name] qui possède les tomes 1 à [ownedUpTo].
ShelfEntry entry(
  String name, {
  NextVolumeInfo? next,
  bool complete = false,
  int ownedUpTo = 3,
}) {
  final series = Series(
    id: name,
    name: name,
    keys: [name.toLowerCase()],
    complete: complete,
    next: next,
  );
  return shelfOf(
    [series],
    [
      for (var n = 1; n <= ownedUpTo; n++)
        Volume(
          id: '$name$n',
          seriesId: name,
          number: n,
          title: '',
          authors: const [],
          lookup: LookupState.found,
          addedAt: DateTime(2026),
        ),
    ],
  ).entries.single;
}

ReleaseDate day(int month, int day) =>
    ReleaseDate(year: 2026, month: month, day: day);

void main() {
  group('toBuyOf', () {
    test('the released volume each series lacks, from A to Z', () {
      final blacksad = entry(
        'Blacksad',
        next: info(4, status: ReleaseStatus.released),
      );
      // Date passée : le tome devrait être sorti.
      final asterix = entry('Astérix', next: info(4, date: day(11, 1)));

      expect(
        toBuyOf([
          blacksad,
          entry('One Piece', next: info(4, date: day(12, 3))),
          asterix,
          entry('Naruto'),
        ], today),
        [
          ShelfPurchase(entry: asterix, number: 4),
          ShelfPurchase(entry: blacksad, number: 4),
        ],
      );
    });

    test('nothing for a closed series or a volume already owned', () {
      expect(
        toBuyOf([
          entry(
            'Closed',
            complete: true,
            next: info(4, status: ReleaseStatus.released),
          ),
          entry('Owned', next: info(2, status: ReleaseStatus.released)),
        ], today),
        isEmpty,
      );
    });
  });

  group('upcomingReleasesOf', () {
    test('the closest dates first, three at most', () {
      final a = entry('A', next: info(4, date: day(12, 20)));
      final b = entry('B', next: info(4, date: day(11, 24)));
      final c = entry('C', next: info(4, date: day(12, 3)));
      final d = entry('D', next: info(4, date: day(12, 31)));

      expect(upcomingReleasesOf([a, b, c, d], today), [
        UpcomingRelease(entry: b, number: 4, date: day(11, 24)),
        UpcomingRelease(entry: c, number: 4, date: day(12, 3)),
        UpcomingRelease(entry: a, number: 4, date: day(12, 20)),
      ]);
      expect(upcomingReleasesOf([a, b, c, d], today, limit: 1), hasLength(1));
    });

    test('a month alone comes after the days of that month, ties by name', () {
      const december = ReleaseDate(year: 2026, month: 12);
      final month = entry('Month', next: info(4, date: december));
      final zed = entry('Zed', next: info(4, date: day(12, 31)));
      final alpha = entry('Alpha', next: info(4, date: day(12, 31)));

      expect(
        [
          for (final release in upcomingReleasesOf([month, zed, alpha], today))
            release.entry.series.name,
        ],
        ['Alpha', 'Zed', 'Month'],
      );
    });

    test('the current month alone still counts as upcoming', () {
      const november = ReleaseDate(year: 2026, month: 11);
      final soon = entry('Soon', next: info(4, date: november));

      expect(upcomingReleasesOf([soon], today), [
        UpcomingRelease(entry: soon, number: 4, date: november),
      ]);
    });

    test('empty without dates, past dates or released volumes', () {
      expect(
        upcomingReleasesOf([
          entry('Undated', next: info(4)),
          entry('Past', next: info(4, date: day(11, 23))),
          entry('Out', next: info(4, status: ReleaseStatus.released)),
          entry('None'),
        ], today),
        isEmpty,
      );
    });
  });
}
