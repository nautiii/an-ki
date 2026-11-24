import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/placement_suggestion.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_backfill.dart';
import 'package:an_ki/features/books/domain/volume_guess.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/domain/volume_number.dart';
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

    test('a call during a pass looks nothing up twice', () async {
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

  group('previous volumes', () {
    const onePiece = Series(
      id: 's1',
      name: 'One Piece',
      keys: ['one piece'],
      complete: false,
    );

    /// Tome scanné [number] de One Piece, publié par [publisher].
    Volume scanned(String isbn, int number, {String? publisher}) => Volume(
      id: isbn,
      seriesId: 's1',
      number: number,
      isbn: isbn,
      title: 'One Piece',
      authors: const [],
      publisher: publisher,
      lookup: LookupState.found,
      addedAt: _now,
    );

    Volume waiting(String id, int number, {DateTime? addedAt}) => Volume(
      id: id,
      seriesId: 's1',
      number: number,
      title: '',
      authors: const [],
      lookup: LookupState.pending,
      addedAt: addedAt ?? _now,
    );

    BookMetadata tome(int number) => BookMetadata(
      title: 'One Piece - Tome $number',
      authors: const ['Eiichirō Oda'],
      publisher: 'Glénat',
      isbn: '978000000000$number',
    );

    test(
      'adds the missing numbers before it at once, then their records',
      () async {
        shelf = RecordingBookshelfRepository(
          series: [onePiece],
          volumes: [
            scanned(_isbn, 5, publisher: 'Glénat'),
            scanned(_other, 2),
          ],
        );
        lookup = RecordingVolumeLookup(
          numbered: {('One Piece', 1): tome(1), ('One Piece', 4): tome(4)},
        );
        final container = makeContainer();
        await settle(container);

        final added = editorOf(container).addPrevious(_isbn);

        expect(added, hasLength(3));
        await pumpEventQueue(times: 200);
        final byNumber = {
          for (final volume in shelf.volumes) volume.number: volume,
        };
        expect(byNumber.keys.toSet(), {1, 2, 3, 4, 5});
        expect([
          for (final n in [1, 3, 4]) byNumber[n]!.id,
        ], unorderedEquals(added));
        expect(lookup.searched, [
          ('One Piece', 1, true),
          ('One Piece', 3, true),
          ('One Piece', 4, true),
        ]);
        expect(lookup.publishers, everyElement('Glénat'));
        final first = byNumber[1]!;
        expect(
          (first.title, first.isbn, first.lookup, first.seriesId),
          ('One Piece - Tome 1', '9780000000001', LookupState.found, 's1'),
        );
        // Inconnu des catalogues : complet tel quel.
        final third = byNumber[3]!;
        expect(
          (third.title, third.isbn, third.lookup),
          ('', null, LookupState.found),
        );
      },
    );

    test('nothing for a volume to sort, volume 1 or no gap', () async {
      shelf = RecordingBookshelfRepository(
        series: [onePiece],
        volumes: [
          scanned(_isbn, 1),
          scanned(_other, 2),
          Volume(
            id: 'loose',
            title: 'Hors-série',
            authors: const [],
            lookup: LookupState.found,
            addedAt: _now,
          ),
        ],
      );
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      expect(editor.addPrevious(_isbn), isEmpty);
      expect(editor.addPrevious(_other), isEmpty);
      expect(editor.addPrevious('loose'), isEmpty);
      expect(editor.addPrevious('unknown'), isEmpty);
      await pumpEventQueue();
      expect(shelf.volumes, hasLength(3));
    });

    test('« Annuler » removes them, a late record brings none back', () async {
      shelf = RecordingBookshelfRepository(
        series: [onePiece],
        volumes: [scanned(_isbn, 3)],
      );
      final gate = Completer<void>();
      lookup = _GatedNumbers(gate.future, {('One Piece', 1): tome(1)});
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      final added = editor.addPrevious(_isbn);
      await pumpEventQueue();
      await editor.removeVolumes(added, uid: 'u1');
      gate.complete();
      await pumpEventQueue(times: 200);

      expect(shelf.volumes.map((v) => v.id), [_isbn]);
      expect(shelf.completedVolumes, isEmpty);
      // Seul le tome déjà parti est cherché ; l'autre, retiré, ne l'est pas.
      expect(lookup.searched, hasLength(1));
    });

    test('tapping twice adds each number once', () async {
      shelf = RecordingBookshelfRepository(
        series: [onePiece],
        volumes: [scanned(_isbn, 3)],
      );
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      final first = editor.addPrevious(_isbn);
      final second = editor.addPrevious(_isbn);
      await pumpEventQueue(times: 200);

      expect(first, hasLength(2));
      expect(second, isEmpty);
      expect(shelf.volumes, hasLength(3));
    });

    test(
      'addNumbers adds the numbers the series lacks, then their records',
      () async {
        shelf = RecordingBookshelfRepository(
          series: [onePiece],
          volumes: [scanned(_isbn, 3, publisher: 'Glénat')],
        );
        lookup = RecordingVolumeLookup(numbered: {('One Piece', 4): tome(4)});
        final container = makeContainer();
        await settle(container);

        // « Acheté » : le tome paru ; le 3 est déjà là, 0 et au-delà du maximum n'existent pas.
        final added = editorOf(container)
            .addNumbers('s1', [4, 3, 4, 0, maxVolumeNumber + 1]);

        expect(added, hasLength(1));
        await pumpEventQueue(times: 200);
        final fourth = shelf.volumes.singleWhere((v) => v.number == 4);
        expect(fourth.id, added.single);
        expect(
          (fourth.title, fourth.lookup, fourth.seriesId),
          ('One Piece - Tome 4', LookupState.found, 's1'),
        );
        expect(lookup.searched, [('One Piece', 4, true)]);
      },
    );

    test('addNumbers: twice adds once, an unknown series nothing', () async {
      shelf = RecordingBookshelfRepository(
        series: [onePiece],
        volumes: [scanned(_isbn, 3)],
      );
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      expect(editor.addNumbers('s1', [1, 2]), hasLength(2));
      expect(editor.addNumbers('s1', [1, 2]), isEmpty);
      expect(editor.addNumbers('unknown', [1]), isEmpty);
      await pumpEventQueue(times: 200);

      expect(shelf.volumes, hasLength(3));
    });

    test('addNumbers adds back a volume whose removal is pending', () async {
      shelf = RecordingBookshelfRepository(
        series: [onePiece],
        volumes: [scanned(_isbn, 3), scanned(_other, 4)],
      );
      final container = makeContainer();
      await settle(container);
      container.read(pendingVolumeRemovalsProvider.notifier).hide(_other);

      // Le tome 4 est retiré (« Annuler » possible) : « Acheté » le rajoute.
      expect(editorOf(container).addNumbers('s1', [4]), hasLength(1));
    });

    test('addNumbers: signed out, nothing is written', () async {
      shelf = RecordingBookshelfRepository(series: [onePiece]);
      final container = makeContainer(uid: null);

      expect(editorOf(container).addNumbers('s1', [1]), isEmpty);
      await pumpEventQueue();
      expect(shelf.volumes, isEmpty);
    });

    test('added during a pass, searched in the next one', () async {
      shelf = RecordingBookshelfRepository(
        series: [onePiece],
        volumes: [waiting('p1', 1), scanned(_isbn, 4)],
      );
      final gate = Completer<void>();
      lookup = _GatedNumbers(gate.future, const {});
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      final pass = editor.completePending();
      await pumpEventQueue();
      final added = editor.addPrevious(_isbn);
      gate.complete();
      await pass;
      await pumpEventQueue(times: 200);

      expect(added, hasLength(2));
      expect(lookup.searched.map((s) => s.$2), [1, 2, 3]);
      expect(shelf.volumes.every((v) => v.lookup == LookupState.found), isTrue);
    });

    test('calls during a pass share its limit', () async {
      shelf = RecordingBookshelfRepository(
        series: [onePiece],
        volumes: [
          for (var n = 1; n <= backfillsPerPass + 5; n++) waiting('p$n', n),
        ],
      );
      final gate = Completer<void>();
      lookup = _GatedNumbers(gate.future, const {});
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      final pass = editor.completePending();
      await pumpEventQueue();
      // Retour dans l'app, une autre page de Livres : pas 40 de plus.
      await editor.completePending();
      await editor.completePending();
      gate.complete();
      await pass;

      expect(lookup.searched, hasLength(backfillsPerPass));
    });

    test(
      'Google down twice: the same volumes wait behind the others',
      () async {
        shelf = RecordingBookshelfRepository(
          series: [onePiece],
          volumes: [waiting('p1', 1), waiting('p2', 2)],
        );
        lookup = RecordingVolumeLookup()..googleAnswers = false;
        final container = makeContainer();
        await settle(container);
        final editor = editorOf(container);

        await editor.completePending();
        await shelf.addManualVolumes('u1', [waiting('p3', 3)]);
        await pumpEventQueue();
        await editor.completePending();

        // p1 et p2 attendent Google : le nouveau venu passe devant eux, et,
        // Google toujours muet, ils ne sont pas redemandés à la BnF.
        expect(lookup.searched.map((s) => s.$2), [1, 2, 3]);
        expect(
          shelf.volumes.every((v) => v.lookup == LookupState.pending),
          isTrue,
        );
      },
    );

    test(
      'another account during a search: nothing written, pass over',
      () async {
        shelf = RecordingBookshelfRepository(
          series: [onePiece],
          volumes: [waiting('p1', 1), waiting('p2', 2)],
        );
        final gate = Completer<void>();
        final gated = _GatedNumbers(gate.future, {('One Piece', 1): tome(1)});
        final uid = NotifierProvider<_Uid, String?>(_Uid.new);
        final container = ProviderContainer.test(
          retry: (_, _) => null,
          overrides: [
            bookshelfRepositoryProvider.overrideWithValue(shelf),
            volumeLookupProvider.overrideWithValue(gated),
            currentUidProvider.overrideWith((ref) => ref.watch(uid)),
            clockProvider.overrideWithValue(() => _now),
          ],
        );
        container.listen(shelfEditorProvider, (_, _) {});
        await settle(container);
        final editor = editorOf(container);

        final pass = editor.completePending();
        await pumpEventQueue();
        container.read(uid.notifier).change('u2');
        // Une page qui s'ouvre sous le nouveau compte demande une passe.
        unawaited(editor.completePending());
        gate.complete();
        await pass;
        await pumpEventQueue();

        expect(gated.searched, hasLength(1));
        expect(shelf.completedVolumes, isEmpty);
      },
    );

    test('another account during a scan lookup: nothing written', () async {
      shelf = RecordingBookshelfRepository(volumes: [_pending(_isbn)]);
      final answer = Completer<IdentifiedVolume?>();
      final uid = NotifierProvider<_Uid, String?>(_Uid.new);
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          bookshelfRepositoryProvider.overrideWithValue(shelf),
          volumeLookupProvider.overrideWithValue(
            _GatedLookup(() => answer.future),
          ),
          currentUidProvider.overrideWith((ref) => ref.watch(uid)),
          clockProvider.overrideWithValue(() => _now),
        ],
      );
      container.listen(shelfEditorProvider, (_, _) {});
      await settle(container);

      final pass = editorOf(container).completePending();
      await pumpEventQueue();
      container.read(uid.notifier).change('u2');
      answer.complete(_onePiece(_isbn));
      await pass;
      await pumpEventQueue();

      expect(shelf.savedVolumes, isEmpty);
      expect(shelf.createdSeries, isEmpty);

      // Aucune série fantôme de l'ancien compte : le nouveau la crée.
      editorOf(container).addSeriesByHand('One Piece', [1], complete: false);
      await pumpEventQueue();
      expect(shelf.createdSeries.single.name, 'One Piece');
    });

    test('another account at « Annuler » removes nothing', () async {
      shelf = RecordingBookshelfRepository(
        series: [onePiece],
        volumes: [scanned(_isbn, 2)],
      );
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      final added = editor.addPrevious(_isbn);
      await pumpEventQueue();
      await editor.removeVolumes(added, uid: 'someone-else');

      expect(shelf.volumes, hasLength(2));
    });

    test('a volume moved during its search is not completed', () async {
      shelf = RecordingBookshelfRepository(
        series: [onePiece],
        volumes: [waiting('p1', 1)],
      );
      final gate = Completer<void>();
      lookup = _GatedNumbers(gate.future, {('One Piece', 1): tome(1)});
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      final pass = editor.completePending();
      await pumpEventQueue();
      await editor.classify('p1', seriesId: 's1', number: 7);
      gate.complete();
      await pass;

      final volume = shelf.volumes.single;
      expect((volume.number, volume.lookup), (7, LookupState.pending));
      expect(shelf.completedVolumes, isEmpty);
    });

    test('a pass completes the oldest first, at most per pass', () async {
      final earlier = _now.subtract(const Duration(days: 1));
      shelf = RecordingBookshelfRepository(
        series: [onePiece],
        volumes: [
          for (var n = backfillsPerPass + 5; n >= 1; n--) waiting('p$n', n),
          waiting('old', 99, addedAt: earlier),
        ],
      );
      final container = makeContainer();
      await settle(container);

      await editorOf(container).completePending();

      expect(lookup.searched, hasLength(backfillsPerPass));
      expect(lookup.searched.first.$2, 99);
      expect(lookup.searched[1].$2, 1);
      expect(
        shelf.volumes.where((v) => v.lookup == LookupState.pending),
        hasLength(6),
      );
    });

    test('a BnF failure stops the pass, nothing is marked', () async {
      shelf = RecordingBookshelfRepository(
        series: [onePiece],
        volumes: [waiting('p1', 1), waiting('p2', 2)],
      );
      lookup = RecordingVolumeLookup()..numberFailure = BookFailure.network;
      final container = makeContainer();
      await settle(container);

      await editorOf(container).completePending();

      expect(lookup.searched, hasLength(1));
      expect(
        shelf.volumes.every((v) => v.lookup == LookupState.pending),
        isTrue,
      );
    });

    test('Google down: the BnF alone for the rest, the unknown wait', () async {
      shelf = RecordingBookshelfRepository(
        series: [onePiece],
        volumes: [waiting('p1', 1), waiting('p2', 2), waiting('p3', 3)],
      );
      lookup = RecordingVolumeLookup(numbered: {('One Piece', 3): tome(3)})
        ..googleAnswers = false;
      final container = makeContainer();
      await settle(container);

      await editorOf(container).completePending();
      await pumpEventQueue();

      expect(lookup.searched, [
        ('One Piece', 1, true),
        ('One Piece', 2, false),
        ('One Piece', 3, false),
      ]);
      expect(
        {for (final v in shelf.volumes) v.id: v.lookup},
        {
          'p1': LookupState.pending,
          'p2': LookupState.pending,
          'p3': LookupState.found,
        },
      );
    });

    test('a series added by hand gets its records too', () async {
      lookup = RecordingVolumeLookup(numbered: {('Blacksad', 2): tome(2)});
      final container = makeContainer();
      await settle(container);

      editorOf(container).addSeriesByHand('Blacksad', [1, 2], complete: false);
      await pumpEventQueue(times: 200);

      expect(lookup.searched.map((s) => s.$2), [1, 2]);
      expect(shelf.volumes.every((v) => v.lookup == LookupState.found), isTrue);
      expect(
        shelf.volumes.singleWhere((v) => v.number == 2).isbn,
        '9780000000002',
      );
    });

    test('a scanned volume replaces the one added without ISBN', () async {
      shelf = RecordingBookshelfRepository(
        series: [onePiece],
        volumes: [
          Volume(
            id: 'by-hand',
            seriesId: 's1',
            number: 108,
            title: '',
            authors: const [],
            lookup: LookupState.found,
            addedAt: _now,
          ),
        ],
      );
      final container = makeContainer();
      await settle(container);

      await editorOf(container).addScanned(_isbn, identified: _onePiece(_isbn));

      final volume = shelf.volumes.single;
      expect((volume.id, volume.number), (_isbn, 108));
    });

    test('two scanned editions of a number both stay', () async {
      shelf = RecordingBookshelfRepository(
        series: [onePiece],
        volumes: [scanned(_other, 108)],
      );
      final container = makeContainer();
      await settle(container);

      await editorOf(container).addScanned(_isbn, identified: _onePiece(_isbn));

      expect(shelf.volumes, hasLength(2));
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

    test('place puts a volume in the suggested series', () async {
      final container = makeContainer();
      await settle(container);

      final seriesId = editorOf(container).place(
        'v1',
        const PlacementSuggestion(
          series: onePiece,
          seriesName: 'One Piece',
          number: 7,
        ),
      );
      await pumpEventQueue();

      expect(seriesId, 's1');
      expect(
        (shelf.volumes.single.seriesId, shelf.volumes.single.number),
        ('s1', 7),
      );
      expect(shelf.createdSeries, isEmpty);
    });

    test('place creates the suggested series first', () async {
      final container = makeContainer();
      await settle(container);

      final seriesId = editorOf(container).place(
        'v1',
        const PlacementSuggestion(seriesName: 'Blacksad', number: 7),
      );
      await pumpEventQueue();

      final created = shelf.createdSeries.single;
      expect((created.id, created.name), (seriesId, 'Blacksad'));
      expect(
        (shelf.volumes.single.seriesId, shelf.volumes.single.number),
        (seriesId, 7),
      );
    });

    Volume loose(String id, String title) => Volume(
      id: id,
      title: title,
      authors: const [],
      lookup: LookupState.found,
      addedAt: _now,
    );

    test('place twice in a new series creates it once', () async {
      shelf = RecordingBookshelfRepository(
        volumes: [
          loose('b6', 'Blacksad tome 6'),
          loose('b7', 'Blacksad tome 7'),
        ],
      );
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      final first = editor.place(
        'b6',
        const PlacementSuggestion(seriesName: 'Blacksad', number: 6),
      );
      final second = editor.place(
        'b7',
        const PlacementSuggestion(seriesName: 'Blacksad', number: 7),
      );
      await pumpEventQueue();

      expect(second, first);
      expect(shelf.createdSeries, hasLength(1));
      expect(
        {for (final v in shelf.volumes) (v.seriesId, v.number)},
        {(first, 6), (first, 7)},
      );
    });

    test('place never uses a series whose removal is pending', () async {
      final container = makeContainer();
      await settle(container);
      container.read(pendingSeriesRemovalsProvider.notifier).hide('s1');

      final seriesId = editorOf(container).place(
        'v1',
        const PlacementSuggestion(
          series: onePiece,
          seriesName: 'One Piece',
          number: 7,
        ),
      );
      await pumpEventQueue();

      expect(seriesId, isNot('s1'));
      expect(shelf.createdSeries.single.name, 'One Piece');
      expect(shelf.volumes.single.seriesId, seriesId);
    });

    test('place: an unknown volume, nothing is written', () async {
      final container = makeContainer();
      await settle(container);

      expect(
        editorOf(container).place(
          'nope',
          const PlacementSuggestion(seriesName: 'Blacksad', number: 7),
        ),
        isNull,
      );
      await pumpEventQueue();
      expect(shelf.createdSeries, isEmpty);
    });

    test('place: signed out, nothing is written', () async {
      final container = makeContainer(uid: null);

      final editor = editorOf(container);

      expect(
        editor.place(
          'v1',
          const PlacementSuggestion(seriesName: 'Blacksad', number: 7),
        ),
        isNull,
      );
      expect(
        editor.place(
          'v1',
          const PlacementSuggestion(
            series: onePiece,
            seriesName: 'One Piece',
            number: 7,
          ),
        ),
        isNull,
      );
      await pumpEventQueue();
      expect(shelf.createdSeries, isEmpty);
      expect(shelf.volumes.single.seriesId, 's2');
    });

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

    test('enters a release date by hand, then clears it', () async {
      final container = makeContainer();
      await settle(container);
      final editor = editorOf(container);

      await editor.enterReleaseDate(
        's1',
        109,
        const ReleaseDate(year: 2026, month: 12, day: 3),
      );
      expect(
        shelf.series.firstWhere((s) => s.id == 's1').next,
        NextVolumeInfo(
          number: 109,
          status: ReleaseStatus.announced,
          date: const ReleaseDate(year: 2026, month: 12, day: 3),
          source: ReleaseSource.user,
          checkedAt: _now,
        ),
      );

      await editor.enterReleaseDate('s1', 109, null);
      expect(shelf.series.firstWhere((s) => s.id == 's1').next, isNull);
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

  /// Aucune notice par numéro, réponse définitive.
  @override
  Future<({BookMetadata? record, bool settled})> findByNumber(
    String seriesName,
    Set<String> keys,
    int number, {
    String? publisher,
    bool askGoogle = true,
  }) async => (record: null, settled: true);
}

/// Session que le test change en cours de route.
class _Uid extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void change(String? uid) => state = uid;
}

/// Recherche par numéro qui attend [_gate] avant de répondre.
class _GatedNumbers extends RecordingVolumeLookup {
  _GatedNumbers(this._gate, Map<(String, int), BookMetadata> numbered)
    : super(numbered: numbered);

  final Future<void> _gate;

  @override
  Future<({BookMetadata? record, bool settled})> findByNumber(
    String seriesName,
    Set<String> keys,
    int number, {
    String? publisher,
    bool askGoogle = true,
  }) async {
    await _gate;
    return super.findByNumber(
      seriesName,
      keys,
      number,
      publisher: publisher,
      askGoogle: askGoogle,
    );
  }
}

/// Étagère dont le flux des tomes est refusé.
class _UnreadableVolumes extends RecordingBookshelfRepository {
  @override
  Stream<List<Volume>> watchVolumes(String uid) =>
      Stream.error(ShelfFailure.denied);
}
