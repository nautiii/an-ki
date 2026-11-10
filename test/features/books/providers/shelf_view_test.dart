import 'dart:async';

import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/providers/shelf_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

const _onePiece = Series(
  id: 's1',
  name: 'One Piece',
  keys: ['one piece'],
  complete: false,
);
const _asterix = Series(
  id: 's2',
  name: 'Astérix',
  keys: ['asterix'],
  complete: false,
);

Volume _volume(String id, {String? seriesId, int? number}) => Volume(
  id: id,
  seriesId: seriesId,
  number: number,
  title: 'Titre $id',
  authors: const [],
  lookup: LookupState.found,
  addedAt: DateTime(2026, 11, 9),
);

/// Flux contrôlés par le test.
class _ControlledShelf extends FakeBookshelfRepository {
  final series = StreamController<List<Series>>();
  final volumes = StreamController<List<Volume>>();

  void close() {
    unawaited(series.close());
    unawaited(volumes.close());
  }

  @override
  Stream<List<Series>> watchSeries(String uid) => series.stream;

  @override
  Stream<List<Volume>> watchVolumes(String uid) => volumes.stream;
}

/// Session que le test change en cours de route.
class _Uid extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void change(String? uid) => state = uid;
}

final _uidProvider = NotifierProvider<_Uid, String?>(_Uid.new);

void main() {
  late RecordingBookshelfRepository repository;

  setUp(() {
    repository = RecordingBookshelfRepository(
      series: const [_onePiece, _asterix],
      volumes: [
        _volume('a', seriesId: 's1', number: 1),
        _volume('b', seriesId: 's2', number: 1),
        _volume('loose'),
      ],
    );
  });

  ProviderContainer makeContainer({BookshelfRepository? shelf}) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(shelf ?? repository),
        currentUidProvider.overrideWith((ref) => ref.watch(_uidProvider)),
      ],
    );
    return container;
  }

  Future<void> load(ProviderContainer container) async {
    await container.read(bookSeriesProvider.future);
    await container.read(bookVolumesProvider.future);
  }

  group('shelfSearchProvider', () {
    test('starts empty and keeps what is typed', () {
      final container = makeContainer();
      container.listen(shelfSearchProvider, (_, _) {});

      expect(container.read(shelfSearchProvider), '');
      container.read(shelfSearchProvider.notifier).update('pie');
      expect(container.read(shelfSearchProvider), 'pie');
    });

    test('resets when the session changes', () {
      final container = makeContainer();
      container.listen(shelfSearchProvider, (_, _) {});
      container.read(shelfSearchProvider.notifier).update('pie');

      container.read(_uidProvider.notifier).change('u2');

      expect(container.read(shelfSearchProvider), '');
    });
  });

  group('shelfSeriesListProvider', () {
    test('lists the series A to Z', () async {
      final container = makeContainer();
      container.listen(shelfSeriesListProvider, (_, _) {});
      await load(container);

      expect(
        container
            .read(shelfSeriesListProvider)
            .requireValue
            .map((e) => e.series.name),
        ['Astérix', 'One Piece'],
      );
    });

    test('filters by the search text', () async {
      final container = makeContainer();
      container.listen(shelfSeriesListProvider, (_, _) {});
      await load(container);

      container.read(shelfSearchProvider.notifier).update('PIE');

      expect(
        container
            .read(shelfSeriesListProvider)
            .requireValue
            .map((e) => e.series.id),
        ['s1'],
      );
    });
  });

  group('seriesEntryProvider', () {
    test('finds the entry of a series', () async {
      final container = makeContainer();
      container.listen(seriesEntryProvider('s1'), (_, _) {});
      await load(container);

      final entry = container.read(seriesEntryProvider('s1')).requireValue;
      expect(entry?.series, _onePiece);
      expect(entry?.owned, [1]);
    });

    test('is null for an unknown id', () async {
      final container = makeContainer();
      container.listen(seriesEntryProvider('nope'), (_, _) {});
      await load(container);

      expect(container.read(seriesEntryProvider('nope')).requireValue, isNull);
    });

    test('is null while its removal is pending', () async {
      final container = makeContainer();
      container.listen(seriesEntryProvider('s1'), (_, _) {});
      await load(container);

      container.read(pendingSeriesRemovalsProvider.notifier).hide('s1');

      expect(container.read(seriesEntryProvider('s1')).requireValue, isNull);
    });

    test('passes the loading and error states of the shelf through', () async {
      final controlled = _ControlledShelf();
      addTearDown(controlled.close);
      final container = makeContainer(shelf: controlled);
      container.listen(seriesEntryProvider('s1'), (_, _) {});
      await pumpEventQueue();

      expect(container.read(seriesEntryProvider('s1')).isLoading, isTrue);

      controlled.series.add(const [_onePiece]);
      controlled.volumes.addError(ShelfFailure.offline);
      await pumpEventQueue();

      expect(
        container.read(seriesEntryProvider('s1')).error,
        ShelfFailure.offline,
      );
    });
  });

  group('volumeByIdProvider', () {
    test('finds a classified and an unclassified volume', () async {
      final container = makeContainer();
      container
        ..listen(volumeByIdProvider('a'), (_, _) {})
        ..listen(volumeByIdProvider('loose'), (_, _) {});
      await load(container);

      expect(container.read(volumeByIdProvider('a')).requireValue?.id, 'a');
      expect(
        container.read(volumeByIdProvider('loose')).requireValue?.id,
        'loose',
      );
    });

    test('follows a classification', () async {
      final container = makeContainer();
      container.listen(volumeByIdProvider('loose'), (_, _) {});
      await load(container);

      await repository.classifyVolume('u1', 'loose', seriesId: 's1', number: 2);
      await pumpEventQueue();

      final volume = container.read(volumeByIdProvider('loose')).requireValue;
      expect((volume?.seriesId, volume?.number), ('s1', 2));
    });

    test('is null once the volume is removed', () async {
      final container = makeContainer();
      container.listen(volumeByIdProvider('a'), (_, _) {});
      await load(container);

      await repository.deleteVolume('u1', 'a');
      await pumpEventQueue();

      expect(container.read(volumeByIdProvider('a')).requireValue, isNull);
    });
  });
}
