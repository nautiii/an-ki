import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_guess.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/providers/burst_scan.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/providers/volume_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

/// ISBN-13 valides (clé de contrôle juste).
const _isbn = '9782344059562';
const _other = '9782723488525';
final _now = DateTime(2026, 11, 11, 10);

IdentifiedVolume _onePiece(String isbn) => IdentifiedVolume(
  isbn: isbn,
  metadata: const BookMetadata(title: 'One Piece', authors: ['Eiichirō Oda']),
  guess: const VolumeGuess(
    seriesName: 'One Piece',
    number: 108,
    confidence: GuessConfidence.high,
  ),
);

/// Trouvé, mais la série n'est devinée qu'en confiance basse.
IdentifiedVolume _lowGuess(String isbn) => IdentifiedVolume(
  isbn: isbn,
  metadata: const BookMetadata(title: 'Coffret Naruto', authors: []),
  guess: const VolumeGuess(
    seriesName: 'Naruto',
    number: 1,
    confidence: GuessConfidence.low,
  ),
);

const _series = Series(
  id: 's1',
  name: 'One Piece',
  keys: ['one piece'],
  complete: false,
);

Volume _owned(String isbn, {String? seriesId = 's1', int? number = 107}) =>
    Volume(
      id: isbn,
      seriesId: seriesId,
      number: number,
      isbn: isbn,
      title: 'One Piece',
      authors: const [],
      lookup: LookupState.found,
      addedAt: _now,
    );

void main() {
  late RecordingBookshelfRepository shelf;
  late VolumeLookup lookup;

  setUp(() {
    shelf = RecordingBookshelfRepository();
    lookup = RecordingVolumeLookup(found: _onePiece);
  });

  Future<ProviderContainer> makeContainer({String? uid = 'u1'}) async {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(shelf),
        volumeLookupProvider.overrideWithValue(lookup),
        currentUidProvider.overrideWithValue(uid),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    // La page tient la rafale en vie, et la rafale l'étagère.
    container.listen(burstScanProvider, (_, _) {});
    container.listen(burstRowsProvider, (_, _) {});
    await settle(container);
    return container;
  }

  BurstScan burstOf(ProviderContainer container) =>
      container.read(burstScanProvider.notifier);

  test('a new ISBN is written and stacks, newest first', () async {
    final container = await makeContainer();

    expect(burstOf(container).scan(_isbn).outcome, ScanOutcome.added);
    expect(burstOf(container).scan(_other).outcome, ScanOutcome.added);
    await settle(container);

    expect(container.read(burstScanProvider), [_other, _isbn]);
    expect(shelf.volumes.map((v) => v.id), containsAll([_isbn, _other]));
    final rows = container.read(burstRowsProvider);
    expect(rows.map((r) => r.isbn), [_other, _isbn]);
    expect(rows.first.status, BurstRowStatus.classified);
    expect((rows.first.seriesName, rows.first.number), ('One Piece', 108));
  });

  test('the camera re-reading a code in the same burst is ignored', () async {
    final container = await makeContainer();

    burstOf(container).scan(_isbn);
    final again = burstOf(container).scan(_isbn);
    await settle(container);

    expect(again.outcome, ScanOutcome.repeated);
    expect(container.read(burstScanProvider), [_isbn]);
    expect((lookup as RecordingVolumeLookup).lookedUp, [_isbn]);
  });

  test('an ISBN already on the shelf says so, writes nothing', () async {
    shelf = RecordingBookshelfRepository(
      series: [_series],
      volumes: [_owned(_isbn)],
    );
    final container = await makeContainer();

    final result = burstOf(container).scan(_isbn);

    expect(result.outcome, ScanOutcome.alreadyOwned);
    expect((result.row?.seriesName, result.row?.number), ('One Piece', 107));
    expect(container.read(burstScanProvider), isEmpty);
    expect(shelf.savedVolumes, isEmpty);
  });

  test('a typed ISBN already in the burst says "already owned"', () async {
    final container = await makeContainer();

    burstOf(container).scan(_isbn);
    final typed = burstOf(container).scan(_isbn, typed: true);

    expect(typed.outcome, ScanOutcome.alreadyOwned);
    expect(container.read(burstScanProvider), [_isbn]);
  });

  test('a code with a wrong check digit is invalid', () async {
    final container = await makeContainer();

    expect(
      burstOf(container).scan('9782344059563').outcome,
      ScanOutcome.invalid,
    );
    expect(container.read(burstScanProvider), isEmpty);
  });

  test('offline, the row waits with "infos à compléter"', () async {
    lookup = RecordingVolumeLookup(failure: BookFailure.network);
    final container = await makeContainer();

    burstOf(container).scan(_isbn);
    await settle(container);

    expect(
      container.read(burstRowsProvider).single.status,
      BurstRowStatus.pending,
    );
    expect(shelf.volumes.single.lookup, LookupState.pending);
  });

  test('an ISBN no catalogue knows is "not found"', () async {
    lookup = RecordingVolumeLookup();
    final container = await makeContainer();

    burstOf(container).scan(_isbn);
    await settle(container);

    expect(
      container.read(burstRowsProvider).single.status,
      BurstRowStatus.notFound,
    );
  });

  test('a low-confidence guess stays unclassified, with its title', () async {
    lookup = RecordingVolumeLookup(found: _lowGuess);
    final container = await makeContainer();

    burstOf(container).scan(_isbn);
    await settle(container);

    final row = container.read(burstRowsProvider).single;
    expect(
      (row.status, row.title),
      (BurstRowStatus.unclassified, 'Coffret Naruto'),
    );
    expect(shelf.createdSeries, isEmpty);
  });

  test(
    'a volume removed for good leaves the burst, can be rescanned',
    () async {
      final container = await makeContainer();
      burstOf(container).scan(_isbn);
      await settle(container);

      await container.read(shelfEditorProvider.notifier).removeVolume(_isbn);
      await settle(container);

      expect(container.read(burstScanProvider), isEmpty);
      expect(burstOf(container).scan(_isbn).outcome, ScanOutcome.added);
    },
  );

  test(
    'while « Annuler » runs, a rescan is ignored; undone, the row is back',
    () async {
      final container = await makeContainer();
      burstOf(container).scan(_isbn);
      await settle(container);

      // Retiré depuis sa feuille : masqué le temps d'« Annuler ».
      final removals = container.read(pendingVolumeRemovalsProvider.notifier)
        ..hide(_isbn);
      await settle(container);
      expect(container.read(burstRowsProvider), isEmpty);
      // La caméra le relit : ni ajouté, ni vibré, ni retenu.
      expect(burstOf(container).scan(_isbn).outcome, ScanOutcome.repeated);

      removals.restore(_isbn);
      await settle(container);

      expect(container.read(burstRowsProvider).single.isbn, _isbn);
      expect(shelf.volumes.single.id, _isbn);
    },
  );

  test('a code read before the shelf is loaded is ignored, not kept', () async {
    final gate = Completer<void>();
    shelf = _SlowShelf(gate.future);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(shelf),
        volumeLookupProvider.overrideWithValue(lookup),
        currentUidProvider.overrideWithValue('u1'),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    container.listen(burstScanProvider, (_, _) {});

    expect(burstOf(container).scan(_isbn).outcome, ScanOutcome.repeated);

    gate.complete();
    await settle(container);
    expect(burstOf(container).scan(_isbn).outcome, ScanOutcome.added);
  });

  test('a new session starts an empty burst', () async {
    final container = await makeContainer();
    burstOf(container).scan(_isbn);

    container.updateOverrides([
      bookshelfRepositoryProvider.overrideWithValue(shelf),
      volumeLookupProvider.overrideWithValue(lookup),
      currentUidProvider.overrideWithValue('u2'),
      clockProvider.overrideWithValue(() => _now),
    ]);
    await settle(container);

    expect(container.read(burstScanProvider), isEmpty);
  });

  group('burstRowOf', () {
    test('pending while the shelf has not loaded', () {
      expect(burstRowOf(_isbn, null).status, BurstRowStatus.pending);
    });
  });

  test('a volume of a series waiting for « Annuler » is ignored', () async {
    shelf = RecordingBookshelfRepository(
      series: [_series],
      volumes: [_owned(_isbn)],
    );
    final container = await makeContainer();
    container.read(pendingSeriesRemovalsProvider.notifier).hide('s1');
    await settle(container);

    expect(burstOf(container).scan(_isbn).outcome, ScanOutcome.repeated);
    expect(container.read(burstScanProvider), isEmpty);
    expect(shelf.savedVolumes, isEmpty);
  });

  test(
    'typed while its removal can be undone, it is "already owned"',
    () async {
      shelf = RecordingBookshelfRepository(
        series: [_series],
        volumes: [_owned(_isbn)],
      );
      final container = await makeContainer();
      container.read(pendingVolumeRemovalsProvider.notifier).hide(_isbn);
      await settle(container);

      final typed = burstOf(container).scan(_isbn, typed: true);

      expect(typed.outcome, ScanOutcome.alreadyOwned);
      expect(shelf.savedVolumes, isEmpty);
    },
  );
}

/// Laisse passer les écritures et les flux de l'étagère.
Future<void> settle(ProviderContainer container) async {
  for (var i = 0; i < 5; i++) {
    await pumpEventQueue();
  }
}

/// Une étagère dont les flux ne répondent qu'une fois [ready] passé.
class _SlowShelf extends RecordingBookshelfRepository {
  _SlowShelf(this.ready);

  final Future<void> ready;

  @override
  Stream<List<Series>> watchSeries(String uid) async* {
    await ready;
    yield* super.watchSeries(uid);
  }

  @override
  Stream<List<Volume>> watchVolumes(String uid) async* {
    await ready;
    yield* super.watchVolumes(uid);
  }
}
