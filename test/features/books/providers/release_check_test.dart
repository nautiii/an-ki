import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bnf_catalog.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/release_check.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

final _now = DateTime(2026, 11, 11, 9);

Series _series(String id, String name, {NextVolumeInfo? next}) => Series(
  id: id,
  name: name,
  keys: [name.toLowerCase()],
  complete: false,
  next: next,
);

Volume _volume(String seriesId, int number) => Volume(
  id: '$seriesId-$number',
  seriesId: seriesId,
  number: number,
  title: 'T$number',
  authors: const [],
  lookup: LookupState.found,
  addedAt: DateTime(2026),
);

BookMetadata _record(String series, int number, {String? date}) => BookMetadata(
  title: series,
  authors: const [],
  seriesTitle: series,
  seriesNumber: number,
  publishedDate: date,
);

void main() {
  late RecordingBookshelfRepository shelf;
  late RecordingBnfCatalog bnf;

  ProviderContainer makeContainer({String? uid = 'u1', Override? session}) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(shelf),
        bnfCatalogProvider.overrideWithValue(bnf),
        session ?? currentUidProvider.overrideWithValue(uid),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    container.listen(releaseCheckProvider, (_, _) {});
    return container;
  }

  ReleaseCheck checkOf(ProviderContainer container) =>
      container.read(releaseCheckProvider.notifier);

  /// Laisse partir les écritures non attendues.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    shelf = RecordingBookshelfRepository(
      series: [_series('op', 'One Piece'), _series('bl', 'Blue Lock')],
      volumes: [_volume('op', 108), _volume('bl', 35)],
    );
    bnf = RecordingBnfCatalog({
      ('One Piece', 109): [_record('One Piece', 109, date: '2026-12-03')],
    });
  });

  group('checkStale', () {
    test('checks every due series and keeps what the BnF says', () async {
      final container = makeContainer();

      await checkOf(container).checkStale();
      await flush();

      expect(
        bnf.asked,
        unorderedEquals([('One Piece', 109), ('Blue Lock', 36)]),
      );
      final bySeries = {for (final s in shelf.series) s.id: s.next};
      expect(
        bySeries['op'],
        NextVolumeInfo(
          number: 109,
          status: ReleaseStatus.announced,
          date: const ReleaseDate(year: 2026, month: 12, day: 3),
          source: ReleaseSource.bnf,
          checkedAt: _now,
        ),
      );
      expect(
        bySeries['bl'],
        NextVolumeInfo(
          number: 36,
          status: ReleaseStatus.unknown,
          source: ReleaseSource.bnf,
          checkedAt: _now,
        ),
      );
      // Rien n'a été demandé : l'état reste au repos.
      expect(container.read(releaseCheckProvider), const AsyncData<void>(null));
    });

    test('skips a series checked this week, or by the user', () async {
      shelf = RecordingBookshelfRepository(
        series: [
          _series(
            'op',
            'One Piece',
            next: NextVolumeInfo(
              number: 109,
              status: ReleaseStatus.unknown,
              source: ReleaseSource.bnf,
              checkedAt: DateTime(2026, 11, 8),
            ),
          ),
          _series(
            'bl',
            'Blue Lock',
            next: NextVolumeInfo(
              number: 36,
              status: ReleaseStatus.announced,
              date: const ReleaseDate(year: 2027, month: 1),
              source: ReleaseSource.user,
              checkedAt: DateTime(2026, 9),
            ),
          ),
        ],
        volumes: [_volume('op', 108), _volume('bl', 35)],
      );
      final container = makeContainer();

      await checkOf(container).checkStale();

      expect(bnf.asked, isEmpty);
    });

    test('a network failure stops the pass and writes nothing', () async {
      bnf.failure = BookFailure.network;
      final container = makeContainer();

      await checkOf(container).checkStale();
      await flush();

      expect(bnf.asked, hasLength(1));
      expect(shelf.series.every((s) => s.next == null), isTrue);
      expect(container.read(releaseCheckProvider), const AsyncData<void>(null));
    });

    test(
      'a series is checked once per session, even if its write fails',
      () async {
        shelf = RecordingBookshelfRepository(
          series: [_series('op', 'One Piece')],
          volumes: [_volume('op', 108)],
          failure: ShelfFailure.denied,
        );
        final container = makeContainer();

        await checkOf(container).checkStale();
        await flush();
        await checkOf(container).checkStale();

        expect(bnf.asked, [('One Piece', 109)]);
        // Un refus en silence : personne n'a rien demandé.
        expect(
          container.read(releaseCheckProvider),
          const AsyncData<void>(null),
        );
      },
    );

    test('writes nothing over what changed during the search', () async {
      final gate = Completer<void>();
      bnf.gate = gate.future;
      final container = makeContainer();

      final pass = checkOf(container).checkStale();
      await flush();
      // L'utilisateur saisit une date pendant la recherche.
      final entered = NextVolumeInfo(
        number: 109,
        status: ReleaseStatus.announced,
        date: const ReleaseDate(year: 2027, month: 2),
        source: ReleaseSource.user,
        checkedAt: _now,
      );
      await shelf.setNextVolume('u1', 'op', entered);
      await flush();
      gate.complete();
      await pass;
      await flush();

      expect(shelf.series.firstWhere((s) => s.id == 'op').next, entered);
      // L'autre série, inchangée, est bien écrite.
      expect(shelf.series.firstWhere((s) => s.id == 'bl').next, isNotNull);
    });

    test('another account signed in meanwhile: nothing written', () async {
      final gate = Completer<void>();
      bnf.gate = gate.future;
      final container = makeContainer(
        session: currentUidProvider.overrideWith(
          (ref) => ref.watch(_uidProvider),
        ),
      );

      final pass = checkOf(container).checkStale();
      await flush();
      container.read(_uidProvider.notifier).set('u2');
      gate.complete();
      await pass;
      await flush();

      expect(shelf.series.every((s) => s.next == null), isTrue);
    });

    test('one pass at a time', () async {
      final gate = Completer<void>();
      bnf.gate = gate.future;
      final container = makeContainer();

      final first = checkOf(container).checkStale();
      await flush();
      await checkOf(container).checkStale();
      gate.complete();
      await first;

      expect(bnf.asked, hasLength(2));
    });

    test('signed out, nothing is asked', () async {
      final container = makeContainer(uid: null);

      await checkOf(container).checkStale();

      expect(bnf.asked, isEmpty);
    });
  });

  group('checkSeries', () {
    test('checks one series now, due or not', () async {
      shelf = RecordingBookshelfRepository(
        series: [
          _series(
            'op',
            'One Piece',
            next: NextVolumeInfo(
              number: 109,
              status: ReleaseStatus.unknown,
              source: ReleaseSource.bnf,
              checkedAt: DateTime(2026, 11, 10),
            ),
          ),
        ],
        volumes: [_volume('op', 108)],
      );
      final container = makeContainer();
      await container.read(releaseCheckProvider.future);
      final states = <AsyncValue<void>>[];
      container.listen(releaseCheckProvider, (_, next) => states.add(next));

      await checkOf(container).checkSeries('op');
      await flush();

      expect(bnf.asked, [('One Piece', 109)]);
      expect(shelf.series.single.next!.status, ReleaseStatus.announced);
      expect(states, [isA<AsyncLoading<void>>(), const AsyncData<void>(null)]);
    });

    test('another account signed in meanwhile: nothing published', () async {
      final gate = Completer<void>();
      bnf.gate = gate.future;
      final container = makeContainer(
        session: currentUidProvider.overrideWith(
          (ref) => ref.watch(_uidProvider),
        ),
      );
      await container.read(releaseCheckProvider.future);

      final check = checkOf(container).checkSeries('op');
      await flush();
      container.read(_uidProvider.notifier).set('u2');
      gate.complete();
      await check;
      await flush();

      expect(shelf.series.every((s) => s.next == null), isTrue);
      expect(container.read(releaseCheckProvider).hasError, isFalse);
    });

    test('publishes a catalog failure', () async {
      bnf.failure = BookFailure.network;
      final container = makeContainer();
      await container.read(releaseCheckProvider.future);

      await checkOf(container).checkSeries('op');

      expect(container.read(releaseCheckProvider).error, BookFailure.network);
    });

    test('publishes a refused write', () async {
      shelf = RecordingBookshelfRepository(
        series: [_series('op', 'One Piece')],
        volumes: [_volume('op', 108)],
        failure: ShelfFailure.denied,
      );
      final container = makeContainer();
      await container.read(releaseCheckProvider.future);

      await checkOf(container).checkSeries('op');
      await flush();

      expect(container.read(releaseCheckProvider).error, ShelfFailure.denied);
    });

    test('an unknown or closed series asks nothing', () async {
      shelf = RecordingBookshelfRepository(
        series: [
          const Series(
            id: 'done',
            name: 'Done',
            keys: ['done'],
            complete: true,
          ),
        ],
      );
      final container = makeContainer();
      await container.read(releaseCheckProvider.future);

      await checkOf(container).checkSeries('done');
      await checkOf(container).checkSeries('nope');

      expect(bnf.asked, isEmpty);
    });
  });
}

/// Compte connecté, changé par le test.
class _Uid extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void set(String? uid) => state = uid;
}

final _uidProvider = NotifierProvider<_Uid, String?>(_Uid.new);
