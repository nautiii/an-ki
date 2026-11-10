import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/widgets/classify_sheet.dart';
import 'package:an_ki/features/books/widgets/shelf_undo.dart';
import 'package:an_ki/features/books/widgets/volume_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/haptics.dart';
import '../../../support/test_harness.dart';

const _series = Series(
  id: 's1',
  name: 'One Piece',
  keys: ['one piece'],
  complete: false,
);

Volume _volume({
  String id = 'v1',
  String? seriesId = 's1',
  int? number = 4,
  String title = 'Romance Dawn',
  LookupState lookup = LookupState.found,
  String? publishedDate = '2013-06-28',
}) => Volume(
  id: id,
  seriesId: seriesId,
  number: number,
  isbn: '9782344059562',
  title: title,
  authors: const ['Eiichirō Oda'],
  publishedDate: publishedDate,
  lookup: lookup,
  addedAt: DateTime(2026, 11, 9),
);

void main() {
  late RecordingBookshelfRepository repository;

  Future<void> openSheet(
    WidgetTester tester,
    RecordingBookshelfRepository repo, {
    String volumeId = 'v1',
  }) async {
    repository = repo;
    await tester.pumpHarness(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => VolumeSheet.show(context, volumeId),
          child: const Text('Ouvrir'),
        ),
      ),
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repo),
        currentUidProvider.overrideWithValue('fake-uid'),
      ],
    );
    await tester.pump();
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  /// Laisse la snackbar se fermer d'elle-même, puis les écritures partir.
  Future<void> letUndoExpire(WidgetTester tester) async {
    await tester.pump(shelfUndoDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the details of a classified volume', (tester) async {
    await openSheet(
      tester,
      RecordingBookshelfRepository(
        series: const [_series],
        volumes: [_volume()],
      ),
    );

    expect(find.text('Romance Dawn'), findsOneWidget);
    expect(find.text('One Piece · tome 4'), findsOneWidget);
    expect(find.text('Eiichirō Oda'), findsOneWidget);
    expect(find.text('Paru le 28 juin 2013'), findsOneWidget);
    expect(find.text('ISBN 9782344059562'), findsOneWidget);
    expect(find.text('Infos à compléter'), findsNothing);
    expect(find.text('Inconnu des catalogues'), findsNothing);
    expect(find.text('Changer de série ou de numéro'), findsOneWidget);
    expect(find.text('Classer'), findsNothing);
  });

  testWidgets('says when the catalogues are still to be asked', (tester) async {
    await openSheet(
      tester,
      RecordingBookshelfRepository(
        series: const [_series],
        volumes: [_volume(lookup: LookupState.pending, title: '')],
      ),
    );

    expect(find.text('Infos à compléter'), findsOneWidget);
    // Sans titre, le tome numéroté se présente par son numéro.
    expect(find.text('Tome 4'), findsOneWidget);
  });

  testWidgets('says when no catalogue knows the book', (tester) async {
    await openSheet(
      tester,
      RecordingBookshelfRepository(
        volumes: [
          _volume(
            seriesId: null,
            number: null,
            lookup: LookupState.notFound,
            publishedDate: null,
          ),
        ],
      ),
    );

    expect(find.text('Inconnu des catalogues'), findsOneWidget);
    expect(find.textContaining('Paru'), findsNothing);
  });

  testWidgets('an unclassified volume offers "Classer"', (tester) async {
    await openSheet(
      tester,
      RecordingBookshelfRepository(
        series: const [_series],
        volumes: [_volume(seriesId: null, number: null)],
      ),
    );

    expect(find.text('Classer'), findsOneWidget);
    expect(find.text('Changer de série ou de numéro'), findsNothing);

    await tester.tap(find.text('Classer'));
    await tester.pumpAndSettle();

    expect(find.byType(ClassifySheet), findsOneWidget);
  });

  testWidgets('removing hides the volume at once, then writes', (tester) async {
    await openSheet(
      tester,
      RecordingBookshelfRepository(
        series: const [_series],
        volumes: [_volume()],
      ),
    );
    final haptics = recordHaptics(tester);

    await tester.tap(find.text('Retirer de la collection'));
    await tester.pumpAndSettle();

    // Retiré tout de suite : feuille fermée, mais encore rattrapable.
    expect(find.byType(VolumeSheet), findsNothing);
    expect(find.text('Romance Dawn retiré de la collection'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(repository.volumes, hasLength(1));
    expect(haptics, ['HapticFeedbackType.mediumImpact']);

    await letUndoExpire(tester);

    expect(repository.volumes, isEmpty);
  });

  testWidgets('"Annuler" keeps the volume', (tester) async {
    await openSheet(
      tester,
      RecordingBookshelfRepository(
        series: const [_series],
        volumes: [_volume()],
      ),
    );

    await tester.tap(find.text('Retirer de la collection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await letUndoExpire(tester);

    expect(repository.volumes.single.id, 'v1');
  });

  testWidgets('closes by itself when the volume disappears elsewhere', (
    tester,
  ) async {
    await openSheet(
      tester,
      RecordingBookshelfRepository(
        series: const [_series],
        volumes: [_volume()],
      ),
    );
    expect(find.byType(VolumeSheet), findsOneWidget);

    await repository.deleteVolume('fake-uid', 'v1');
    await tester.pumpAndSettle();

    expect(find.byType(VolumeSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an empty sheet for an unknown volume', (tester) async {
    await openSheet(
      tester,
      RecordingBookshelfRepository(
        series: const [_series],
        volumes: [_volume()],
      ),
      volumeId: 'nope',
    );

    expect(find.text('Retirer de la collection'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
