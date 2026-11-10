import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/shelf_offline.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/screens/series_screen.dart';
import 'package:an_ki/features/books/widgets/offline_banner.dart';
import 'package:an_ki/features/books/widgets/volume_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

Volume _volume(int number) => Volume(
  id: 'v$number',
  seriesId: 's1',
  number: number,
  title: 'Tome $number',
  authors: const [],
  lookup: LookupState.found,
  addedAt: DateTime(2026),
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
  final next = NextVolumeInfo(
    number: 5,
    status: ReleaseStatus.announced,
    date: const ReleaseDate(year: 2026, month: 12, day: 3),
    source: ReleaseSource.bnf,
    checkedAt: DateTime(2026, 11, 8),
  );

  RecordingBookshelfRepository filled() => RecordingBookshelfRepository(
    series: [
      Series(
        id: 's1',
        name: 'One Piece',
        keys: const ['one piece'],
        complete: false,
        next: next,
      ),
      const Series(id: 's2', name: 'Naruto', keys: ['naruto'], complete: false),
    ],
    volumes: [_volume(1), _volume(2), _volume(4)],
  );

  Future<void> pumpSeries(
    WidgetTester tester,
    BookshelfRepository repository, {
    String id = 's1',
    List<Object> extra = const [],
    Map<String, WidgetBuilder>? routes,
  }) async {
    await tester.pumpHarness(
      SeriesScreen(seriesId: id),
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repository),
        currentUidProvider.overrideWithValue('fake-uid'),
        todayProvider.overrideWithValue(DateTime(2026, 11, 8)),
        ...extra,
      ],
      routes: routes,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the header, the next card, the holes and the grid', (
    tester,
  ) async {
    await pumpSeries(tester, filled());

    // Le nom est le titre de la barre et l'en-tête de la page.
    expect(find.text('One Piece'), findsNWidgets(2));
    expect(find.text('Prochain'), findsOneWidget);
    expect(find.text('Tome 5 · sortie le 3 décembre'), findsOneWidget);
    expect(find.text('selon la BnF · vérifié le 8 nov.'), findsOneWidget);
    expect(find.text('Il vous manque'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Tome 3'), findsOneWidget);
    expect(find.text('Vos tomes'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
  });

  testWidgets('an empty series says it has no volume', (tester) async {
    await pumpSeries(tester, filled(), id: 's2');

    expect(
      find.text('Aucun tome de cette série pour l\'instant.'),
      findsOneWidget,
    );
    expect(find.text('Il vous manque'), findsNothing);
  });

  testWidgets('a volume of the grid opens its sheet', (tester) async {
    await pumpSeries(tester, filled());

    await tester.tap(find.bySemanticsLabel('Tome 2, possédé'));
    await tester.pumpAndSettle();

    expect(find.byType(VolumeSheet), findsOneWidget);
  });

  testWidgets('an unknown series has its own message and goes back', (
    tester,
  ) async {
    await pumpSeries(
      tester,
      filled(),
      id: 'nope',
      routes: {AppRoutes.books: (_) => const Text('Page étagère')},
    );

    expect(find.text('Série introuvable'), findsOneWidget);
    expect(find.byTooltip('Options de la série'), findsNothing);

    await tester.tap(find.text("Retour à l'étagère"));
    await tester.pumpAndSettle();

    expect(find.text('Page étagère'), findsOneWidget);
  });

  testWidgets('shows a skeleton while loading', (tester) async {
    await tester.pumpHarness(
      const SeriesScreen(seriesId: 's1'),
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(filled()),
        currentUidProvider.overrideWithValue('fake-uid'),
        shelfProvider.overrideWithValue(const AsyncLoading()),
      ],
    );
    await tester.pump();

    expect(find.byType(SkeletonBox), findsWidgets);
  });

  testWidgets('shows the error and retries', (tester) async {
    final repository = _Flaky();
    await pumpSeries(tester, repository);

    expect(find.text('Série indisponible'), findsOneWidget);

    repository.broken = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('Série indisponible'), findsNothing);
    expect(find.text('Série introuvable'), findsOneWidget);
  });

  testWidgets('says the network is missing, or something generic', (
    tester,
  ) async {
    await pumpSeries(tester, _Flaky());
    expect(
      find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
      findsOneWidget,
    );
  });

  testWidgets('a refused read does not blame the network', (tester) async {
    await pumpSeries(tester, _Flaky()..error = ShelfFailure.denied);

    expect(
      find.text("Quelque chose s'est mal passé. Réessayez dans un instant."),
      findsOneWidget,
    );
    expect(
      find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
      findsNothing,
    );
  });

  testWidgets('closes when its series is deleted meanwhile', (tester) async {
    final repository = filled();
    await pumpSeries(tester, repository);
    expect(find.byType(SeriesScreen), findsOneWidget);

    await repository.deleteSeries('fake-uid', 's1');
    await tester.pumpAndSettle();

    expect(find.byType(SeriesScreen), findsNothing);
  });

  testWidgets('closes with its rename dialog when the series disappears', (
    tester,
  ) async {
    final repository = filled();
    await pumpSeries(tester, repository);
    await tester.tap(find.byTooltip('Options de la série'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renommer'));
    await tester.pumpAndSettle();
    expect(find.text('Renommer la série'), findsOneWidget);

    await repository.deleteSeries('fake-uid', 's1');
    await tester.pumpAndSettle();

    expect(find.text('Renommer la série'), findsNothing);
    expect(find.byType(SeriesScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closes when deleted from its own menu', (tester) async {
    await pumpSeries(tester, filled());

    await tester.tap(find.byTooltip('Options de la série'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer la série'));
    await tester.pumpAndSettle();

    expect(find.byType(SeriesScreen), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('shows the offline banner after the grace period', (
    tester,
  ) async {
    final repository = filled()..offline = true;
    await tester.pumpHarness(
      const SeriesScreen(seriesId: 's1'),
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repository),
        currentUidProvider.overrideWithValue('fake-uid'),
        todayProvider.overrideWithValue(DateTime(2026, 11, 8)),
      ],
    );
    await tester.pump();
    expect(find.byType(OfflineBanner), findsNothing);

    await tester.pump(ShelfOffline.grace);
    await tester.pump();

    expect(find.byType(OfflineBanner), findsOneWidget);
  });

  testWidgets('meets the tap target and label guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSeries(tester, filled());

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('holds at 200 % text without overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpSeries(tester, filled());

    expect(tester.takeException(), isNull);
    expect(find.text('One Piece'), findsWidgets);
  });
}
