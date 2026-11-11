import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bnf_catalog.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_guess.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/providers/volume_lookup.dart';
import 'package:an_ki/features/books/widgets/pending_completer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

const _isbn = '9782344059562';

IdentifiedVolume _found(String isbn) => IdentifiedVolume(
  isbn: isbn,
  metadata: const BookMetadata(title: 'One Piece', authors: ['Eiichirō Oda']),
  guess: const VolumeGuess(
    seriesName: 'One Piece',
    number: 1,
    confidence: GuessConfidence.high,
  ),
);

final _pending = Volume(
  id: _isbn,
  isbn: _isbn,
  title: '',
  authors: const [],
  lookup: LookupState.pending,
  addedAt: DateTime(2026, 11, 9),
);

void main() {
  late RecordingBookshelfRepository repository;

  late RecordingBnfCatalog bnf;

  Future<void> mount(
    WidgetTester tester,
    RecordingVolumeLookup lookup, {
    bool tickers = true,
    bool checkReleases = false,
  }) async {
    repository = RecordingBookshelfRepository(
      series: [
        const Series(
          id: 's1',
          name: 'One Piece',
          keys: ['one piece'],
          complete: false,
        ),
      ],
      volumes: [_pending],
    );
    bnf = RecordingBnfCatalog();
    await tester.pumpHarness(
      TickerMode(
        enabled: tickers,
        child: PendingCompleter(
          checkReleases: checkReleases,
          child: const Text('Contenu'),
        ),
      ),
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repository),
        volumeLookupProvider.overrideWithValue(lookup),
        bnfCatalogProvider.overrideWithValue(bnf),
        currentUidProvider.overrideWithValue('fake-uid'),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> resume(WidgetTester tester) async {
    // Les transitions légales, une à une : l'app part en arrière-plan puis
    // revient.
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('mounting completes the pending volumes, once', (tester) async {
    final lookup = RecordingVolumeLookup(found: _found);

    await mount(tester, lookup);

    expect(find.text('Contenu'), findsOneWidget);
    expect(lookup.lookedUp, [_isbn]);
    expect(repository.volumes.single.lookup, LookupState.found);
  });

  testWidgets('an app resume runs another pass', (tester) async {
    // Hors ligne au départ : le tome reste en attente, la reprise le retente.
    final lookup = RecordingVolumeLookup(failure: BookFailure.network);
    await mount(tester, lookup);
    expect(lookup.lookedUp, [_isbn]);

    await resume(tester);

    expect(lookup.lookedUp, [_isbn, _isbn]);
  });

  testWidgets('a hidden tab does not run a pass on resume', (tester) async {
    final lookup = RecordingVolumeLookup(failure: BookFailure.network);
    await mount(tester, lookup, tickers: false);
    final before = lookup.lookedUp.length;

    await resume(tester);

    expect(lookup.lookedUp, hasLength(before));
  });

  testWidgets('a network failure leaves the volume pending', (tester) async {
    final lookup = RecordingVolumeLookup(failure: BookFailure.network);

    await mount(tester, lookup);

    expect(repository.volumes.single.lookup, LookupState.pending);
  });

  testWidgets('only the shelf checks the release dates', (tester) async {
    final lookup = RecordingVolumeLookup(failure: BookFailure.network);

    await mount(tester, lookup);
    expect(bnf.asked, isEmpty);
  });

  testWidgets('the shelf checks the release dates on opening and resume', (
    tester,
  ) async {
    final lookup = RecordingVolumeLookup(failure: BookFailure.network);
    await mount(tester, lookup, checkReleases: true);
    // Une série sans tome : son prochain est le 1.
    expect(bnf.asked, [('One Piece', 1)]);

    await resume(tester);

    // Vérifiée une fois par session : la reprise ne la redemande pas.
    expect(bnf.asked, [('One Piece', 1)]);
  });
}
