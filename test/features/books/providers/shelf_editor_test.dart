import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_guess.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';

import 'package:an_ki/features/books/providers/volume_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

/// ISBN-13 valide (clé de contrôle juste).
const _isbn = '9782344059562';
const _other = '9782723488525';
final _now = DateTime(2026, 11, 9, 10);

IdentifiedVolume _onePiece(String isbn, {int number = 108}) => IdentifiedVolume(
  isbn: isbn,
  metadata: const BookMetadata(
    title: 'One Piece',
    subtitle: 'Le tome',
    authors: ['Eiichirō Oda'],
    publisher: 'Glénat',
    imageUrl: 'https://img/op.jpg',
  ),
  guess: VolumeGuess(
    seriesName: 'One Piece',
    number: number,
    confidence: GuessConfidence.high,
  ),
);

Volume _pending(String isbn) => Volume(
  id: isbn,
  isbn: isbn,
  title: '',
  authors: const [],
  lookup: LookupState.pending,
  addedAt: _now,
);

void main() {
  late RecordingBookshelfRepository shelf;
  late RecordingVolumeLookup lookup;

  /// Recherche à la place de [lookup] quand un test la donne.
  _GatedLookup? gated;

  ProviderContainer makeContainer({String? uid = 'u1'}) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(shelf),
        volumeLookupProvider.overrideWithValue(gated ?? lookup),
        currentUidProvider.overrideWithValue(uid),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    // L'écran tient l'éditeur en vie ; l'éditeur, lui, tient les flux de
    // l'étagère (aucun écouteur ici sur shelfProvider).
    container.listen(shelfEditorProvider, (_, _) {});
    return container;
  }

  ShelfEditor editorOf(ProviderContainer container) =>
      container.read(shelfEditorProvider.notifier);

  Future<void> settle(ProviderContainer container) async {
    await container.read(bookSeriesProvider.future);
    await container.read(bookVolumesProvider.future);
  }

  setUp(() {
    shelf = RecordingBookshelfRepository();
    lookup = RecordingVolumeLookup(found: _onePiece);
    gated = null;
  });

  group('addScanned', () {
    test(
      'writes the volume pending, then completes it in a new series',
      () async {
        final container = makeContainer();
        await settle(container);

        await editorOf(container).addScanned(_isbn);

        expect(shelf.savedVolumes.first, _pending(_isbn));
        expect(
          shelf.createdSeries.single,
          const Series(
            id: 'series-0',
            name: 'One Piece',
            keys: ['one piece'],
            complete: false,
          ),
        );
        expect(
          shelf.volumes.single,
          Volume(
            id: _isbn,
            seriesId: 'series-0',
            number: 108,
            isbn: _isbn,
            title: 'One Piece : Le tome',
            authors: const ['Eiichirō Oda'],
            imageUrl: 'https://img/op.jpg',
            publisher: 'Glénat',
            lookup: LookupState.found,
            addedAt: _now,
          ),
        );
        expect(
          container.read(shelfEditorProvider),
          const AsyncData<void>(null),
        );
      },
    );

    test('a volume already identified is not looked up again', () async {
      final container = makeContainer();
      await settle(container);

      await editorOf(container).addScanned(_isbn, identified: _onePiece(_isbn));

      expect(lookup.lookedUp, isEmpty);
      expect(shelf.volumes.single.lookup, LookupState.found);
    });

    test('two volumes of a new series create it once', () async {
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      await Future.wait([editor.addScanned(_isbn), editor.addScanned(_other)]);

      expect(shelf.createdSeries, hasLength(1));
      expect(shelf.volumes.map((v) => v.seriesId).toSet(), {
        shelf.createdSeries.single.id,
      });
    });

    test('joins the series that carries its key', () async {
      shelf = RecordingBookshelfRepository(
        series: const [
          Series(
            id: 's1',
            name: 'ONE PIECE',
            keys: ['one piece'],
            complete: false,
          ),
        ],
      );
      final container = makeContainer();
      await settle(container);

      await editorOf(container).addScanned(_isbn);

      expect(shelf.createdSeries, isEmpty);
      expect(shelf.volumes.single.seriesId, 's1');
    });

    test('a doubtful guess leaves the volume unclassified', () async {
      lookup = RecordingVolumeLookup(
        found: (isbn) => IdentifiedVolume(
          isbn: isbn,
          metadata: const BookMetadata(
            title: 'Tome 12 - One Piece',
            authors: [],
          ),
          guess: const VolumeGuess(
            seriesName: 'One Piece',
            number: 12,
            confidence: GuessConfidence.low,
          ),
        ),
      );
      final container = makeContainer();
      await settle(container);

      await editorOf(container).addScanned(_isbn);

      expect(shelf.createdSeries, isEmpty);
      expect(shelf.volumes.single.seriesId, isNull);
      expect(shelf.volumes.single.lookup, LookupState.found);
    });

    test('a book nobody knows is marked not found', () async {
      lookup = RecordingVolumeLookup();
      final container = makeContainer();
      await settle(container);

      await editorOf(container).addScanned(_isbn);

      expect(shelf.volumes.single.lookup, LookupState.notFound);
    });

    test('offline, the volume stays pending without an error', () async {
      lookup = RecordingVolumeLookup(failure: BookFailure.network);
      final container = makeContainer();
      await settle(container);

      await editorOf(container).addScanned(_isbn);

      expect(shelf.volumes.single, _pending(_isbn));
      expect(container.read(shelfEditorProvider).hasError, isFalse);
    });

    test('a volume already found is left as it is', () async {
      final found = Volume(
        id: _isbn,
        seriesId: 's9',
        number: 3,
        isbn: _isbn,
        title: 'Rangé',
        authors: const [],
        lookup: LookupState.found,
        addedAt: DateTime(2025),
      );
      shelf = RecordingBookshelfRepository(volumes: [found]);
      final container = makeContainer();
      await settle(container);

      await editorOf(container).addScanned(_isbn);

      expect(shelf.savedVolumes, isEmpty);
      expect(lookup.lookedUp, isEmpty);
    });

    test('a not found volume rescanned is looked up again', () async {
      shelf = RecordingBookshelfRepository(
        volumes: [
          Volume(
            id: _isbn,
            isbn: _isbn,
            title: '',
            authors: const [],
            lookup: LookupState.notFound,
            addedAt: DateTime(2025),
          ),
        ],
      );
      final container = makeContainer();
      await settle(container);

      await editorOf(container).addScanned(_isbn);

      expect(shelf.savedVolumes.single.lookup, LookupState.found);
      expect(shelf.savedVolumes.single.addedAt, DateTime(2025));
    });

    test('a wrong check digit is an invalid ISBN, nothing written', () async {
      final container = makeContainer();
      await settle(container);

      await editorOf(container).addScanned('9782344059568');

      expect(
        container.read(shelfEditorProvider).error,
        ShelfFailure.invalidIsbn,
      );
      expect(shelf.savedVolumes, isEmpty);
    });

    test('a refused write is published as an error', () async {
      shelf = RecordingBookshelfRepository(failure: ShelfFailure.denied);
      final container = makeContainer();
      await settle(container);

      await editorOf(container).addScanned(_isbn);

      expect(container.read(shelfEditorProvider).error, ShelfFailure.denied);
    });

    test('signed out, nothing happens', () async {
      final container = makeContainer(uid: null);

      await editorOf(container).addScanned(_isbn);

      expect(shelf.savedVolumes, isEmpty);
      expect(lookup.lookedUp, isEmpty);
    });
  });

  group('a lookup that ends late', () {
    late Completer<IdentifiedVolume?> answer;

    setUp(() {
      answer = Completer<IdentifiedVolume?>();
      gated = _GatedLookup(() => answer.future);
    });

    test('does not bring back a volume removed meanwhile', () async {
      shelf = RecordingBookshelfRepository(volumes: [_pending(_isbn)]);
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      final pass = editor.completePending();
      await pumpEventQueue();
      await editor.removeVolume(_isbn);
      await pumpEventQueue();
      answer.complete(_onePiece(_isbn));
      await pass;

      expect(shelf.volumes, isEmpty);
      expect(shelf.createdSeries, isEmpty);
    });

    test('keeps the place given meanwhile', () async {
      shelf = RecordingBookshelfRepository(volumes: [_pending(_isbn)]);
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      final pass = editor.completePending();
      await pumpEventQueue();
      await editor.classify(_isbn, seriesId: 'mine', number: 2);
      await pumpEventQueue();
      answer.complete(_onePiece(_isbn));
      await pass;

      final volume = shelf.volumes.single;
      expect(
        (volume.seriesId, volume.number, volume.lookup),
        ('mine', 2, LookupState.found),
      );
      expect(shelf.createdSeries, isEmpty);
    });

    test('a second pass while one runs does nothing', () async {
      shelf = RecordingBookshelfRepository(volumes: [_pending(_isbn)]);
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      final first = editor.completePending();
      await editor.completePending();
      answer.complete(_onePiece(_isbn));
      await first;

      expect(gated?.calls, 1);
    });
  });

  test('a refused new series is forgotten by the next scans', () async {
    shelf = RecordingBookshelfRepository(failure: ShelfFailure.denied);
    final container = makeContainer();
    await settle(container);
    final editor = editorOf(container);
    await editor.addScanned(_isbn, identified: _onePiece(_isbn));

    // L'étagère accepte de nouveau : le scan suivant recrée la série.
    shelf = RecordingBookshelfRepository();
    final next = makeContainer();
    await settle(next);
    await editorOf(next).addScanned(_other, identified: _onePiece(_other));

    expect(shelf.createdSeries, hasLength(1));
    expect(shelf.volumes.single.seriesId, shelf.createdSeries.single.id);
  });

  group('completePending', () {
    test('completes every pending volume in turn', () async {
      shelf = RecordingBookshelfRepository(
        volumes: [_pending(_isbn), _pending(_other)],
      );
      final container = makeContainer();
      await settle(container);

      await editorOf(container).completePending();

      expect(lookup.lookedUp, [_isbn, _other]);
      expect(shelf.volumes.every((v) => v.lookup == LookupState.found), isTrue);
    });

    test('a network error stops the pass, nothing marked not found', () async {
      shelf = RecordingBookshelfRepository(
        volumes: [_pending(_isbn), _pending(_other)],
      );
      lookup = RecordingVolumeLookup(failure: BookFailure.quotaExceeded);
      final container = makeContainer();
      await settle(container);

      await editorOf(container).completePending();

      expect(lookup.lookedUp, [_isbn]);
      expect(
        shelf.volumes.every((v) => v.lookup == LookupState.pending),
        isTrue,
      );
    });

    test('a pending volume already classified keeps its place', () async {
      shelf = RecordingBookshelfRepository(
        volumes: [
          Volume(
            id: _isbn,
            seriesId: 'mine',
            number: 7,
            isbn: _isbn,
            title: '',
            authors: const [],
            lookup: LookupState.pending,
            addedAt: _now,
          ),
        ],
      );
      final container = makeContainer();
      await settle(container);

      await editorOf(container).completePending();

      expect(
        (shelf.volumes.single.seriesId, shelf.volumes.single.number),
        ('mine', 7),
      );
      expect(shelf.createdSeries, isEmpty);
    });

    test('waits for the first read of the volumes', () async {
      shelf = RecordingBookshelfRepository(volumes: [_pending(_isbn)]);
      final container = makeContainer();

      // Sans `settle` : les tomes ne sont pas encore lus.
      await editorOf(container).completePending();

      expect(lookup.lookedUp, [_isbn]);
      expect(shelf.volumes.single.lookup, LookupState.found);
    });

    test('an unreadable shelf starts nothing, state unchanged', () async {
      shelf = _UnreadableVolumes();
      final container = makeContainer();
      final before = container.read(shelfEditorProvider);

      await editorOf(container).completePending();

      expect(lookup.lookedUp, isEmpty);
      expect(container.read(shelfEditorProvider), before);
      expect(container.read(shelfEditorProvider).isLoading, isFalse);
    });
  });

  group('addSeriesByHand', () {
    const onePiece = Series(
      id: 's1',
      name: 'One Piece',
      keys: ['one piece', 'op'],
      complete: false,
    );

    Volume owned(String id, int number) => Volume(
      id: id,
      seriesId: 's1',
      number: number,
      title: '',
      authors: const [],
      lookup: LookupState.found,
      addedAt: _now,
    );

    test('a series waiting for « Annuler » is not joined', () async {
      shelf = RecordingBookshelfRepository(series: [onePiece]);
      final container = makeContainer();
      await settle(container);
      container.read(pendingSeriesRemovalsProvider.notifier).hide('s1');

      final id = editorOf(container)
          .addSeriesByHand('One Piece', [1], complete: false);
      await pumpEventQueue();

      expect(id, isNot('s1'));
      expect(shelf.createdSeries.single.name, 'One Piece');
      expect(shelf.volumes.single.seriesId, id);
    });

    test('creates a series named as typed, one volume per number', () async {
      final container = makeContainer();
      await settle(container);

      final id = editorOf(container)
          .addSeriesByHand('  Blacksad ', [1, 2, 5], complete: false);
      await pumpEventQueue();

      expect(id, 'series-0');
      expect(
        shelf.createdSeries.single,
        const Series(
          id: 'series-0',
          name: 'Blacksad',
          keys: ['blacksad'],
          complete: false,
        ),
      );
      expect(shelf.volumes.map((v) => v.number), [1, 2, 5]);
      expect(shelf.volumes.every((v) => v.seriesId == 'series-0'), isTrue);
      expect(
        shelf.volumes.every(
          (v) =>
              v.lookup == LookupState.found &&
              v.isbn == null &&
              v.addedAt == _now,
        ),
        isTrue,
      );
    });

    test('a name with the key of a series joins it', () async {
      shelf = RecordingBookshelfRepository(series: const [onePiece]);
      final container = makeContainer();
      await settle(container);

      final id = editorOf(container)
          .addSeriesByHand('one piece', [3], complete: false);
      await pumpEventQueue();

      expect(id, 's1');
      expect(shelf.createdSeries, isEmpty);
      expect(shelf.series, hasLength(1));
      expect(shelf.volumes.single.seriesId, 's1');
    });

    test('an old key of a series joins it too', () async {
      shelf = RecordingBookshelfRepository(series: const [onePiece]);
      final container = makeContainer();
      await settle(container);

      final id = editorOf(container)
          .addSeriesByHand('OP', [3], complete: false);
      await pumpEventQueue();

      expect(id, 's1');
      expect(shelf.createdSeries, isEmpty);
    });

    test('numbers the series already owns are skipped', () async {
      shelf = RecordingBookshelfRepository(
        series: const [onePiece],
        volumes: [owned('a', 1), owned('b', 2)],
      );
      final container = makeContainer();
      await settle(container);

      editorOf(container)
          .addSeriesByHand('One Piece', [1, 2, 3], complete: false);
      await pumpEventQueue();

      expect(shelf.volumes.map((v) => v.number).toSet(), {1, 2, 3});
      expect(shelf.volumes, hasLength(3));
    });

    test('complete creates a complete series', () async {
      final container = makeContainer();
      await settle(container);

      editorOf(container).addSeriesByHand('Blacksad', [1], complete: true);
      await pumpEventQueue();

      expect(shelf.createdSeries.single.complete, isTrue);
    });

    test('complete marks an existing series complete', () async {
      shelf = RecordingBookshelfRepository(series: const [onePiece]);
      final container = makeContainer();
      await settle(container);

      editorOf(container).addSeriesByHand('One Piece', [1], complete: true);
      await pumpEventQueue();

      expect(shelf.series.single.complete, isTrue);
    });

    test('not complete never reopens a complete series', () async {
      shelf = RecordingBookshelfRepository(
        series: const [
          Series(
            id: 's1',
            name: 'One Piece',
            keys: ['one piece'],
            complete: true,
          ),
        ],
      );
      final container = makeContainer();
      await settle(container);

      editorOf(container).addSeriesByHand('One Piece', [1], complete: false);
      await pumpEventQueue();

      expect(shelf.series.single.complete, isTrue);
      expect(shelf.volumes, hasLength(1));
    });

    test('an empty name writes nothing', () async {
      final container = makeContainer();
      await settle(container);

      final id = editorOf(container).addSeriesByHand('  ', [1], complete: true);
      await pumpEventQueue();

      expect(id, isNull);
      expect(shelf.createdSeries, isEmpty);
      expect(shelf.volumes, isEmpty);
    });

    test('signed out, nothing is written', () async {
      final container = makeContainer(uid: null);

      final id = editorOf(container)
          .addSeriesByHand('Blacksad', [1], complete: false);
      await pumpEventQueue();

      expect(id, isNull);
      expect(shelf.createdSeries, isEmpty);
      expect(shelf.volumes, isEmpty);
    });
  });

  group('corrections', () {
    const onePiece = Series(
      id: 's1',
      name: 'One Piece',
      keys: ['one piece'],
      complete: false,
    );
    const onePieceFr = Series(
      id: 's2',
      name: 'One-Piece (FR)',
      keys: ['one piece fr'],
      complete: false,
    );
    final volume = Volume(
      id: 'v1',
      seriesId: 's2',
      number: 4,
      isbn: _isbn,
      title: 'T4',
      authors: const [],
      lookup: LookupState.found,
      addedAt: _now,
    );

    setUp(() {
      shelf = RecordingBookshelfRepository(
        series: const [onePiece, onePieceFr],
        volumes: [volume],
      );
    });

    test(
      'classify moves a volume; without a series it loses its number',
      () async {
        final container = makeContainer();
        await settle(container);
        final editor = editorOf(container);

        await editor.classify('v1', seriesId: 's1', number: 5);
        expect(
          (shelf.volumes.single.seriesId, shelf.volumes.single.number),
          ('s1', 5),
        );

        await editor.classify('v1', number: 5);
        expect(
          (shelf.volumes.single.seriesId, shelf.volumes.single.number),
          (null, null),
        );
      },
    );

    test('removes a volume', () async {
      final container = makeContainer();
      await settle(container);

      await editorOf(container).removeVolume('v1');

      expect(shelf.volumes, isEmpty);
    });

    test('deletes a series with its volumes', () async {
      final container = makeContainer();
      await settle(container);

      await editorOf(container).deleteSeries('s2');

      expect(shelf.series.map((s) => s.id), ['s1']);
      expect(shelf.volumes, isEmpty);
    });

    test('a failed series deletion is published as an error', () async {
      shelf = RecordingBookshelfRepository(
        series: const [onePiece],
        failure: ShelfFailure.denied,
      );
      final container = makeContainer();
      await settle(container);

      await editorOf(container).deleteSeries('s1');

      expect(container.read(shelfEditorProvider).error, ShelfFailure.denied);
    });

    test(
      'detaches the volumes of a deleted series that have no number',
      () async {
        shelf = RecordingBookshelfRepository(
          series: const [onePiece],
          volumes: [
            Volume(
              id: 'n',
              seriesId: 's1',
              number: 2,
              title: 'T2',
              authors: const [],
              lookup: LookupState.found,
              addedAt: _now,
            ),
            Volume(
              id: 'x',
              seriesId: 's1',
              title: 'Sans numéro',
              authors: const [],
              lookup: LookupState.found,
              addedAt: _now,
            ),
          ],
        );
        final container = makeContainer();
        await settle(container);

        await editorOf(container).deleteSeries('s1');

        expect(shelf.volumes.map((v) => v.id), ['x']);
        expect(shelf.volumes.single.seriesId, isNull);
      },
    );

    test('an action started by another account writes nothing', () async {
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      await editor.deleteSeries('s1', uid: 'other');
      await editor.removeVolume('v1', uid: 'other');
      await editor.mergeSeries(sourceId: 's2', targetId: 's1', uid: 'other');
      await editor.setComplete('s1', complete: true, uid: 'other');

      expect(shelf.series.map((s) => s.id), ['s1', 's2']);
      expect(shelf.volumes.single.seriesId, 's2');
      expect(shelf.series.first.complete, isFalse);
    });

    test('an action started by the current account is written', () async {
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      await editor.setComplete('s1', complete: true, uid: 'u1');
      await editor.removeVolume('v1', uid: 'u1');
      await editor.mergeSeries(sourceId: 's2', targetId: 's1', uid: 'u1');
      await editor.deleteSeries('s1', uid: 'u1');

      expect(shelf.series, isEmpty);
      expect(shelf.volumes, isEmpty);
    });

    test('signed out, an action started earlier writes nothing', () async {
      final container = makeContainer(uid: null);
      await settle(container);

      await editorOf(container).deleteSeries('s1', uid: 'u1');
      await editorOf(container).removeVolume('v1', uid: 'u1');

      expect(shelf.series, hasLength(2));
      expect(shelf.volumes, hasLength(1));
    });

    test('creates a series and returns its id at once', () async {
      final container = makeContainer();
      await settle(container);

      final id = editorOf(container).createSeries('  Blacksad ');
      await pumpEventQueue();

      expect(id, 'series-0');
      expect(
        shelf.createdSeries.single,
        const Series(
          id: 'series-0',
          name: 'Blacksad',
          keys: ['blacksad'],
          complete: false,
        ),
      );
      expect(editorOf(container).createSeries('  '), isNull);
    });

    test('renames a series, keeping its old key', () async {
      final container = makeContainer();
      await settle(container);

      await editorOf(container).renameSeries('s1', 'Piece One ');
      await editorOf(container).renameSeries('s1', ' ');

      expect(
        shelf.series.firstWhere((s) => s.id == 's1'),
        const Series(
          id: 's1',
          name: 'Piece One',
          keys: ['one piece', 'piece one'],
          complete: false,
        ),
      );
    });

    test('merges a series with its keys and the key of its name', () async {
      final container = makeContainer();
      await settle(container);

      await editorOf(container).mergeSeries(sourceId: 's2', targetId: 's1');

      expect(shelf.series, [
        const Series(
          id: 's1',
          name: 'One Piece',
          keys: ['one piece', 'one piece fr'],
          complete: false,
        ),
      ]);
      expect(shelf.volumes.single.seriesId, 's1');
    });

    test('marks complete, sets and clears the next volume', () async {
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);
      final next = NextVolumeInfo(
        number: 109,
        status: ReleaseStatus.announced,
        date: const ReleaseDate(year: 2026, month: 12),
        source: ReleaseSource.user,
        checkedAt: _now,
      );

      await editor.setComplete('s1', complete: true);
      await editor.setNext('s1', next);
      var series = shelf.series.firstWhere((s) => s.id == 's1');
      expect((series.complete, series.next), (true, next));

      await editor.setNext('s1', null);
      series = shelf.series.firstWhere((s) => s.id == 's1');
      expect(series.next, isNull);
    });

    test('a failed correction is published as an error', () async {
      shelf = RecordingBookshelfRepository(
        volumes: [volume],
        failure: ShelfFailure.offline,
      );
      final container = makeContainer();
      await settle(container);

      await editorOf(container).removeVolume('v1');

      expect(container.read(shelfEditorProvider).error, ShelfFailure.offline);
    });
  });
}

/// Recherche qui répond quand le test le décide.
class _GatedLookup extends Fake implements VolumeLookup {
  _GatedLookup(this._answer);

  final Future<IdentifiedVolume?> Function() _answer;
  var calls = 0;

  @override
  Future<IdentifiedVolume?> lookUp(String isbn) {
    calls++;
    return _answer();
  }
}

/// Étagère dont le flux des tomes est refusé.
class _UnreadableVolumes extends RecordingBookshelfRepository {
  @override
  Stream<List<Volume>> watchVolumes(String uid) =>
      Stream.error(ShelfFailure.denied);
}
