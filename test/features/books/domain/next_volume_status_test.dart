import 'package:an_ki/features/books/domain/next_volume_status.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 11, 8);

NextVolumeInfo info({
  int number = 109,
  ReleaseStatus status = ReleaseStatus.unknown,
  ReleaseDate? date,
  ReleaseSource source = ReleaseSource.user,
}) => NextVolumeInfo(
  number: number,
  status: status,
  date: date,
  source: source,
  checkedAt: DateTime(2026, 11),
);

/// Étagère d'une série qui possède les tomes 1 à [ownedUpTo].
ShelfEntry entry({
  NextVolumeInfo? next,
  bool complete = false,
  int ownedUpTo = 108,
}) {
  final series = Series(
    id: 'op',
    name: 'One Piece',
    keys: const ['one piece'],
    complete: complete,
    next: next,
  );
  final volumes = [
    for (var n = 1; n <= ownedUpTo; n++)
      Volume(
        id: '$n',
        seriesId: 'op',
        number: n,
        title: 'T$n',
        authors: const [],
        lookup: LookupState.found,
        addedAt: DateTime(2026),
      ),
  ];
  return shelfOf([series], volumes).entries.single;
}

void main() {
  group('nextVolumeStatus', () {
    test('a closed series is complete, whatever it knows', () {
      expect(
        nextVolumeStatus(
          entry(complete: true, next: info(status: ReleaseStatus.released)),
          today,
        ),
        NextVolumeStatus.complete,
      );
    });

    test('unknown without any information', () {
      expect(nextVolumeStatus(entry(), today), NextVolumeStatus.unknown);
    });

    test('released when the source says the volume is out', () {
      final status = nextVolumeStatus(
        entry(next: info(status: ReleaseStatus.released)),
        today,
      );

      expect(status, NextVolumeStatus.released);
    });

    test('released when the source says so without a date', () {
      expect(
        nextVolumeStatus(
          entry(
            next: info(
              status: ReleaseStatus.released,
              source: ReleaseSource.bnf,
            ),
          ),
          today,
        ),
        NextVolumeStatus.released,
      );
    });

    group('with a date', () {
      NextVolumeStatus statusOn(String iso, {ReleaseStatus? status}) =>
          nextVolumeStatus(
            entry(
              next: info(
                status: status ?? ReleaseStatus.announced,
                date: ReleaseDate.tryParse(iso),
              ),
            ),
            today,
          );

      test('announced for a day after today', () {
        expect(statusOn('2026-12-03'), NextVolumeStatus.announced);
        expect(statusOn('2026-11-09'), NextVolumeStatus.announced);
      });

      test('announced today', () {
        expect(statusOn('2026-11-08'), NextVolumeStatus.announced);
      });

      test('released once the day has passed', () {
        expect(statusOn('2026-11-07'), NextVolumeStatus.released);
        expect(statusOn('2025-12-31'), NextVolumeStatus.released);
      });

      test('a month is announced until it ends', () {
        expect(statusOn('2026-12'), NextVolumeStatus.announced);
        expect(statusOn('2026-11'), NextVolumeStatus.announced);
        expect(statusOn('2026-10'), NextVolumeStatus.released);
      });

      test('a future date wins over an unknown status', () {
        expect(
          statusOn('2026-12-03', status: ReleaseStatus.unknown),
          NextVolumeStatus.announced,
        );
      });

      test('a past date wins over an announced status', () {
        expect(
          statusOn('2026-01-15', status: ReleaseStatus.announced),
          NextVolumeStatus.released,
        );
      });

      test('only the calendar day of today matters', () {
        final status = nextVolumeStatus(
          entry(
            next: info(
              status: ReleaseStatus.announced,
              date: const ReleaseDate(year: 2026, month: 11, day: 8),
            ),
          ),
          DateTime(2026, 11, 8, 23, 59, 59),
        );

        expect(status, NextVolumeStatus.announced);
      });
    });

    test('an announcement without a date tells nothing', () {
      expect(
        nextVolumeStatus(
          entry(next: info(status: ReleaseStatus.announced)),
          today,
        ),
        NextVolumeStatus.unknown,
      );
    });

    test('information about a volume the user already owns is stale', () {
      expect(
        nextVolumeStatus(
          entry(next: info(number: 108, status: ReleaseStatus.released)),
          today,
        ),
        NextVolumeStatus.unknown,
      );
      expect(
        nextVolumeStatus(
          entry(
            next: info(
              number: 50,
              status: ReleaseStatus.announced,
              date: const ReleaseDate(year: 2027, month: 1),
            ),
          ),
          today,
        ),
        NextVolumeStatus.unknown,
      );
    });

    test('information about a hole is still about a volume not owned', () {
      final series = Series(
        id: 'op',
        name: 'One Piece',
        keys: const ['one piece'],
        complete: false,
        next: info(number: 2, status: ReleaseStatus.released),
      );
      final shelf = shelfOf(
        [series],
        [
          Volume(
            id: '1',
            seriesId: 'op',
            number: 1,
            title: 'T1',
            authors: const [],
            lookup: LookupState.found,
            addedAt: DateTime(2026),
          ),
          Volume(
            id: '3',
            seriesId: 'op',
            number: 3,
            title: 'T3',
            authors: const [],
            lookup: LookupState.found,
            addedAt: DateTime(2026),
          ),
        ],
      );

      expect(
        nextVolumeStatus(shelf.entries.single, today),
        NextVolumeStatus.released,
      );
    });
  });
}
