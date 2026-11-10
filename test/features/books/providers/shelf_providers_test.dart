import 'dart:async';

import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

const _series = Series(
  id: 's1',
  name: 'One Piece',
  keys: ['one piece'],
  complete: false,
);
final _volume = Volume(
  id: 'v1',
  seriesId: 's1',
  number: 1,
  title: 'T1',
  authors: const [],
  lookup: LookupState.found,
  addedAt: DateTime(2026, 11, 9),
);

/// Série lue une fois vide, puis refusée, à chaque (re)lecture.
class _Denied extends FakeBookshelfRepository {
  @override
  Stream<List<Series>> watchSeries(String uid) async* {
    yield const [];
    throw ShelfFailure.denied;
  }

  @override
  Stream<List<Volume>> watchVolumes(String uid) => Stream.value(const []);
}

/// Flux contrôlés par le test.
class _ControlledShelf extends FakeBookshelfRepository {
  final series = StreamController<List<Series>>();
  final volumes = StreamController<List<Volume>>();
  final watchedUids = <String>[];

  /// Ferme les flux sans attendre : un flux jamais écouté ne finit pas.
  void close() {
    unawaited(series.close());
    unawaited(volumes.close());
  }

  @override
  Stream<List<Series>> watchSeries(String uid) {
    watchedUids.add(uid);
    return series.stream;
  }

  @override
  Stream<List<Volume>> watchVolumes(String uid) => volumes.stream;
}

void main() {
  ProviderContainer makeContainer(
    BookshelfRepository repository, {
    String? uid = 'u1',
  }) => ProviderContainer.test(
    retry: (_, _) => null,
    overrides: [
      bookshelfRepositoryProvider.overrideWithValue(repository),
      currentUidProvider.overrideWithValue(uid),
    ],
  );

  test('joins both streams of the signed-in user into a shelf', () async {
    final repository = RecordingBookshelfRepository(
      series: const [_series],
      volumes: [_volume],
    );
    final container = makeContainer(repository);
    container.listen(shelfProvider, (_, _) {});

    await container.read(bookSeriesProvider.future);
    await container.read(bookVolumesProvider.future);

    expect(
      container.read(shelfProvider).value,
      shelfOf(const [_series], [_volume]),
    );
  });

  test('loads until both streams have spoken, fails if one fails', () async {
    final repository = _ControlledShelf();
    addTearDown(repository.close);
    final container = makeContainer(repository);
    container.listen(shelfProvider, (_, _) {});
    await pumpEventQueue();

    expect(container.read(shelfProvider), isA<AsyncLoading<Shelf>>());
    expect(repository.watchedUids, ['u1']);

    repository.series.add(const [_series]);
    await pumpEventQueue();
    expect(container.read(shelfProvider), isA<AsyncLoading<Shelf>>());

    repository.volumes.addError(ShelfFailure.denied);
    await pumpEventQueue();
    expect(container.read(shelfProvider).error, ShelfFailure.denied);
  });

  test('signed out, the shelf is empty and nothing is watched', () async {
    final repository = _ControlledShelf();
    addTearDown(repository.close);
    final container = makeContainer(repository, uid: null);
    container.listen(shelfProvider, (_, _) {});
    await container.read(bookSeriesProvider.future);
    await container.read(bookVolumesProvider.future);

    expect(
      container.read(shelfProvider).value,
      const Shelf(entries: [], unclassified: []),
    );
    expect(repository.watchedUids, isEmpty);
  });

  group('pending removals', () {
    final other = Volume(
      id: 'v2',
      seriesId: 's1',
      number: 2,
      title: 'T2',
      authors: const [],
      lookup: LookupState.found,
      addedAt: DateTime(2026, 11, 9),
    );
    final loose = Volume(
      id: 'v3',
      title: 'Hors série',
      authors: const [],
      lookup: LookupState.found,
      addedAt: DateTime(2026, 11, 9),
    );

    Future<ProviderContainer> loaded() async {
      final container = makeContainer(
        RecordingBookshelfRepository(
          series: const [_series],
          volumes: [_volume, other, loose],
        ),
      );
      container.listen(shelfProvider, (_, _) {});
      await container.read(bookSeriesProvider.future);
      await container.read(bookVolumesProvider.future);
      return container;
    }

    test('a pending series keeps its volumes without a valid number', () async {
      final repository = RecordingBookshelfRepository(
        series: const [_series],
        volumes: [
          _volume,
          Volume(
            id: 'none',
            seriesId: 's1',
            title: 'Sans numéro',
            authors: const [],
            lookup: LookupState.found,
            addedAt: DateTime(2026, 11, 9),
          ),
          Volume(
            id: 'zero',
            seriesId: 's1',
            number: 0,
            title: 'Zéro',
            authors: const [],
            lookup: LookupState.found,
            addedAt: DateTime(2026, 11, 9),
          ),
          Volume(
            id: 'big',
            seriesId: 's1',
            number: 1001,
            title: 'Trop grand',
            authors: const [],
            lookup: LookupState.found,
            addedAt: DateTime(2026, 11, 9),
          ),
        ],
      );
      final container = makeContainer(repository);
      container.listen(shelfProvider, (_, _) {});
      await container.read(bookSeriesProvider.future);
      await container.read(bookVolumesProvider.future);

      container.read(pendingSeriesRemovalsProvider.notifier).hide('s1');

      final shelf = container.read(shelfProvider).requireValue;
      expect(shelf.entries, isEmpty);
      expect(shelf.unclassified.map((v) => v.id).toSet(), {
        'none',
        'zero',
        'big',
      });
    });

    test('a pending series is hidden with its volumes', () async {
      final container = await loaded();

      container.read(pendingSeriesRemovalsProvider.notifier).hide('s1');

      final shelf = container.read(shelfProvider).requireValue;
      expect(shelf.entries, isEmpty);
      // Ses tomes ne retombent pas dans « à classer » : ils partent avec elle.
      expect(shelf.unclassified.map((v) => v.id), ['v3']);
    });

    test('a pending volume is hidden alone', () async {
      final container = await loaded();

      container.read(pendingVolumeRemovalsProvider.notifier).hide('v2');

      final shelf = container.read(shelfProvider).requireValue;
      expect(shelf.entries.single.owned, [1]);
    });

    test('restoring brings them back', () async {
      final container = await loaded();
      container.read(pendingSeriesRemovalsProvider.notifier).hide('s1');
      container.read(pendingVolumeRemovalsProvider.notifier).hide('v3');

      container.read(pendingSeriesRemovalsProvider.notifier).restore('s1');
      container.read(pendingVolumeRemovalsProvider.notifier).restore('v3');

      final shelf = container.read(shelfProvider).requireValue;
      expect(shelf.entries.single.owned, [1, 2]);
      expect(shelf.unclassified.map((v) => v.id), ['v3']);
    });
  });

  test('a refused read is an error even while Riverpod retries it', () async {
    final container = ProviderContainer.test(
      retry: (_, _) => const Duration(seconds: 1),
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(_Denied()),
        currentUidProvider.overrideWithValue('u1'),
      ],
    );
    container.listen(shelfProvider, (_, _) {});
    await pumpEventQueue();

    // La série a répondu [] avant le refus : jamais une étagère vide.
    final shelf = container.read(shelfProvider);
    expect(shelf, isA<AsyncError<Shelf>>());
    expect(shelf.error, ShelfFailure.denied);
  });
}
