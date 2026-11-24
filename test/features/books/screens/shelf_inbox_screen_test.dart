import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/providers/volume_lookup.dart';
import 'package:an_ki/features/books/screens/shelf_inbox_screen.dart';
import 'package:an_ki/features/books/widgets/classify_sheet.dart';
import 'package:an_ki/features/books/widgets/volume_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/haptics.dart';
import '../../../support/test_harness.dart';

Volume _volume(
  String id, {
  String title = '',
  LookupState lookup = LookupState.found,
  DateTime? at,
  List<String> authors = const [],
}) => Volume(
  id: id,
  isbn: '978$id',
  title: title,
  authors: authors,
  lookup: lookup,
  addedAt: at ?? DateTime(2026, 11, 9),
);

/// Dépôt dont la lecture échoue tant que [broken] est vrai.
class _Flaky extends RecordingBookshelfRepository {
  bool broken = true;
  Object error = ShelfFailure.offline;

  @override
  Stream<List<Series>> watchSeries(String uid) =>
      broken ? Stream.error(error) : super.watchSeries(uid);
}

void main() {
  RecordingBookshelfRepository filled() => RecordingBookshelfRepository(
    series: const [
      Series(id: 's1', name: 'One Piece', keys: ['one piece'], complete: false),
    ],
    volumes: [
      _volume(
        'old',
        title: 'Vieux tome',
        at: DateTime(2026, 11),
        authors: const ['Oda'],
      ),
      _volume('new', lookup: LookupState.pending),
    ],
  );

  Future<void> pumpInbox(
    WidgetTester tester,
    BookshelfRepository repository, {
    Map<String, WidgetBuilder>? routes,
  }) async {
    await tester.pumpHarness(
      const ShelfInboxScreen(),
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repository),
        currentUidProvider.overrideWithValue('fake-uid'),
        // Hors ligne : la page complète les tomes en attente à l'ouverture,
        // celui-ci reste « infos à compléter ».
        volumeLookupProvider.overrideWithValue(
          RecordingVolumeLookup(failure: BookFailure.network),
        ),
      ],
      routes: routes,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('says everything is sorted when the inbox is empty', (
    tester,
  ) async {
    await pumpInbox(tester, RecordingBookshelfRepository());

    expect(find.text('Tout est rangé'), findsOneWidget);
    expect(find.text('À classer (0)'), findsOneWidget);
    expect(find.text('Classer'), findsNothing);
  });

  testWidgets('lists the volumes, most recent first', (tester) async {
    await pumpInbox(tester, filled());

    expect(find.text('À classer (2)'), findsOneWidget);
    // Sans titre : l'ISBN ; la recherche en attente est dite.
    expect(find.text('ISBN 978new'), findsOneWidget);
    expect(find.text('Infos à compléter'), findsOneWidget);
    expect(find.text('Vieux tome'), findsOneWidget);
    expect(find.text('Oda'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('ISBN 978new')).dy,
      lessThan(tester.getTopLeft(find.text('Vieux tome')).dy),
    );
  });

  testWidgets('"Classer" opens the classification', (tester) async {
    await pumpInbox(tester, filled());

    await tester.tap(find.text('Classer').first);
    await tester.pumpAndSettle();

    expect(find.byType(ClassifySheet), findsOneWidget);
  });

  testWidgets('a suggested series takes the volume in one tap', (tester) async {
    final repository = RecordingBookshelfRepository(
      series: const [
        Series(
          id: 's1',
          name: 'One Piece',
          keys: ['one piece'],
          complete: false,
        ),
      ],
      volumes: [_volume('op', title: 'One Piece - Tome 13')],
    );
    final haptics = recordHaptics(tester);
    await pumpInbox(
      tester,
      repository,
      routes: {AppRoutes.series('s1'): (_) => const Text('Page série')},
    );

    expect(
      find.text('AnKi propose un rangement : un toucher suffit.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ranger dans One Piece · t. 13'));
    await tester.pump();

    final volume = repository.volumes.single;
    expect((volume.seriesId, volume.number), ('s1', 13));
    expect(find.text('Rangé dans One Piece · tome 13'), findsOneWidget);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    // La ligne est partie ; « Voir » ouvre quand même la série.
    expect(find.text('One Piece - Tome 13'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();

    expect(find.text('Page série'), findsOneWidget);
  });

  testWidgets('an owned number is never filed in one tap', (tester) async {
    Volume scanned(String isbn, {String title = '', int? number}) => Volume(
      id: isbn,
      isbn: isbn,
      seriesId: number == null ? null : 's1',
      number: number,
      title: title,
      authors: const [],
      lookup: LookupState.found,
      addedAt: DateTime(2026, 11, 9),
    );
    final repository = RecordingBookshelfRepository(
      series: const [
        Series(
          id: 's1',
          name: 'One Piece',
          keys: ['one piece'],
          complete: false,
        ),
      ],
      volumes: [
        scanned('9782723400001', number: 13),
        scanned('9782723400002', title: 'One Piece - Tome 13'),
      ],
    );
    await pumpInbox(tester, repository);

    expect(find.byTooltip('Autre série'), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Tome 13 déjà dans One Piece, choisir où ranger ce tome',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Tome 13 déjà dans One Piece'));
    await tester.pumpAndSettle();

    expect(find.byType(ClassifySheet), findsOneWidget);
    expect(
      find.text(
        'Vous avez déjà ce tome, il comptera comme un deuxième exemplaire.',
      ),
      findsOneWidget,
    );
    expect(repository.volumes.where((v) => v.seriesId == null), hasLength(1));
  });

  testWidgets('no promise of a suggestion when there is none', (tester) async {
    await pumpInbox(
      tester,
      RecordingBookshelfRepository(
        volumes: [_volume('new', lookup: LookupState.pending)],
      ),
    );

    expect(find.textContaining('AnKi propose'), findsNothing);
    expect(find.text('Classer'), findsOneWidget);
  });

  testWidgets('a guessed number shows on « Créer »', (tester) async {
    await pumpInbox(
      tester,
      RecordingBookshelfRepository(
        volumes: [_volume('n', title: 'Naruto - Tome 13')],
      ),
    );

    expect(
      find.text('Créer «\u00a0Naruto\u00a0» · t.\u00a013'),
      findsOneWidget,
    );
  });

  testWidgets('a long suggestion wraps at 200 % text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpInbox(
      tester,
      RecordingBookshelfRepository(
        volumes: [_volume('a', title: "L'Atelier des sorciers - Tome 12")],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.text("Créer «\u00a0L'Atelier des sorciers\u00a0» · t.\u00a012"),
      findsOneWidget,
    );
  });

  testWidgets('a new series is created for the volume', (tester) async {
    final repository = filled();
    await pumpInbox(tester, repository);

    await tester.tap(find.text('Créer «\u00a0Vieux tome\u00a0»'));
    await tester.pump();

    final created = repository.createdSeries.single;
    expect(created.name, 'Vieux tome');
    expect(
      repository.volumes.singleWhere((v) => v.id == 'old').seriesId,
      created.id,
    );
  });

  testWidgets('« Autre série » opens the whole classification', (tester) async {
    await pumpInbox(tester, filled());

    await tester.tap(find.byTooltip('Autre série'));
    await tester.pumpAndSettle();

    expect(find.byType(ClassifySheet), findsOneWidget);
  });

  testWidgets('the suggestion is read in full', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpInbox(tester, filled());

    expect(
      find.bySemanticsLabel('Créer la série Vieux tome, tome 1'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Vieux tome, Oda'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the row opens the whole volume', (tester) async {
    await pumpInbox(tester, filled());

    await tester.tap(find.text('Vieux tome'));
    await tester.pumpAndSettle();

    expect(find.byType(VolumeSheet), findsOneWidget);
  });

  testWidgets('shows a skeleton while loading', (tester) async {
    await tester.pumpHarness(
      const ShelfInboxScreen(),
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(filled()),
        currentUidProvider.overrideWithValue('fake-uid'),
        shelfProvider.overrideWithValue(const AsyncLoading()),
      ],
    );
    await tester.pump();

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.text('Classer'), findsWidgets);
  });

  testWidgets('shows the error and retries', (tester) async {
    final repository = _Flaky();
    await pumpInbox(tester, repository);

    expect(find.text('Étagère indisponible'), findsOneWidget);

    repository.broken = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('Tout est rangé'), findsOneWidget);
  });

  testWidgets('says the network is missing, or something generic', (
    tester,
  ) async {
    await pumpInbox(tester, _Flaky());
    expect(
      find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
      findsOneWidget,
    );
  });

  testWidgets('a refused read does not blame the network', (tester) async {
    await pumpInbox(tester, _Flaky()..error = ShelfFailure.denied);

    expect(
      find.text("Quelque chose s'est mal passé. Réessayez dans un instant."),
      findsOneWidget,
    );
    expect(
      find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
      findsNothing,
    );
  });

  testWidgets('meets the tap target and label guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpInbox(tester, filled());

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('stacks its rows at 200 % text without overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpInbox(tester, filled());

    expect(tester.takeException(), isNull);
  });
}
