import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/legacy_import.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:an_ki/features/books/providers/shelf_offline.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/screens/shelf_screen.dart';
import 'package:an_ki/features/books/widgets/offline_banner.dart';
import 'package:an_ki/features/books/widgets/series_tile.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

const _profile = UserProfile(
  id: 'fake-uid',
  name: 'Camille',
  surname: 'Durand',
  locale: 'fr',
);

Series _series(String id, String name, {NextVolumeInfo? next}) => Series(
  id: id,
  name: name,
  keys: [name.toLowerCase()],
  complete: false,
  next: next,
);

Volume _volume(String id, {String? seriesId, int? number, DateTime? at}) =>
    Volume(
      id: id,
      seriesId: seriesId,
      number: number,
      isbn: '978$id',
      title: 'Titre $id',
      authors: const [],
      lookup: LookupState.found,
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
  final next = NextVolumeInfo(
    number: 109,
    status: ReleaseStatus.announced,
    date: const ReleaseDate(year: 2026, month: 12, day: 3),
    source: ReleaseSource.bnf,
    checkedAt: DateTime(2026, 11, 8),
  );

  List<Object> overrides(BookshelfRepository repository) => [
    bookshelfRepositoryProvider.overrideWithValue(repository),
    currentUidProvider.overrideWithValue('fake-uid'),
    todayProvider.overrideWithValue(DateTime(2026, 11, 8)),
    userProfileProvider.overrideWithValue(const AsyncData(_profile)),
  ];

  RecordingBookshelfRepository filled() => RecordingBookshelfRepository(
    series: [
      _series('s1', 'One Piece', next: next),
      _series('s2', 'Naruto'),
      _series('s3', 'Astérix'),
    ],
    volumes: [
      _volume('a', seriesId: 's1', number: 1),
      _volume('b', seriesId: 's2', number: 1),
      _volume('c', seriesId: 's3', number: 1),
      _volume('loose1'),
      _volume('loose2'),
    ],
  );

  Future<void> pumpShelf(
    WidgetTester tester,
    BookshelfRepository repository, {
    List<Object>? extra,
    Map<String, WidgetBuilder>? routes,
  }) async {
    await tester.pumpHarness(
      const ShelfScreen(),
      overrides: [...overrides(repository), ...?extra],
      routes: routes,
    );
    await tester.pumpAndSettle();
  }

  group('first run', () {
    testWidgets('invites to scan, with no manual add', (tester) async {
      await pumpShelf(tester, RecordingBookshelfRepository());

      expect(find.text('Votre étagère vous attend'), findsOneWidget);
      expect(find.text('Scanner un livre'), findsOneWidget);
      expect(find.text('Ajouter'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('the button opens the scanner', (tester) async {
      await pumpShelf(
        tester,
        RecordingBookshelfRepository(),
        routes: {AppRoutes.booksScan: (_) => const Text('Page scan')},
      );

      await tester.tap(find.text('Scanner un livre'));
      await tester.pumpAndSettle();

      expect(find.text('Page scan'), findsOneWidget);
    });

    testWidgets('the app bar action opens the scanner too', (tester) async {
      await pumpShelf(
        tester,
        filled(),
        routes: {AppRoutes.booksScan: (_) => const Text('Page scan')},
      );

      await tester.tap(find.byTooltip('Scanner un livre'));
      await tester.pumpAndSettle();

      expect(find.text('Page scan'), findsOneWidget);
    });

    testWidgets('the settings avatar opens the settings', (tester) async {
      await pumpShelf(
        tester,
        filled(),
        routes: {AppRoutes.settings: (_) => const Text('Page réglages')},
      );

      await tester.tap(find.byTooltip('Paramètres'));
      await tester.pumpAndSettle();

      expect(find.text('Page réglages'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('shows a skeleton while loading', (tester) async {
      await tester.pumpHarness(
        const ShelfScreen(),
        overrides: [
          ...overrides(RecordingBookshelfRepository()),
          shelfProvider.overrideWithValue(const AsyncLoading()),
        ],
      );
      // Pas de pumpAndSettle : le squelette s'anime sans fin.
      await tester.pump();

      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.text('Votre étagère vous attend'), findsNothing);
    });

    testWidgets('shows the error and "Réessayer" reads the shelf again', (
      tester,
    ) async {
      final repository = _Flaky();
      await pumpShelf(tester, repository);

      expect(find.text('Étagère indisponible'), findsOneWidget);

      repository.broken = false;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Étagère indisponible'), findsNothing);
      expect(find.text('Votre étagère vous attend'), findsOneWidget);
    });

    testWidgets('offline says the network is missing', (tester) async {
      await pumpShelf(tester, _Flaky());

      expect(
        find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
        findsOneWidget,
      );
    });

    testWidgets('a refused read says something generic, not the network', (
      tester,
    ) async {
      await pumpShelf(tester, _Flaky()..error = ShelfFailure.denied);

      expect(find.text('Étagère indisponible'), findsOneWidget);
      expect(
        find.text("Quelque chose s'est mal passé. Réessayez dans un instant."),
        findsOneWidget,
      );
      expect(
        find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
        findsNothing,
      );
    });

    testWidgets('the offline banner is hidden while the error shows', (
      tester,
    ) async {
      final repository = _Flaky()..offline = true;
      await tester.pumpHarness(
        const ShelfScreen(),
        overrides: overrides(repository),
      );
      await tester.pump(ShelfOffline.grace * 2);
      await tester.pump();

      expect(find.text('Étagère indisponible'), findsOneWidget);
      expect(find.byType(OfflineBanner), findsNothing);
    });

    testWidgets('lists the series A to Z', (tester) async {
      await pumpShelf(tester, filled());

      final tops = [
        for (final name in ['Astérix', 'Naruto', 'One Piece'])
          tester.getTopLeft(find.text(name)).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(find.byType(SeriesTile), findsNWidgets(3));
    });

    testWidgets('a tile opens its series', (tester) async {
      await pumpShelf(
        tester,
        filled(),
        routes: {AppRoutes.seriesPattern: (_) => const Text('Page série')},
      );

      await tester.tap(find.text('One Piece'));
      await tester.pumpAndSettle();

      expect(find.text('Page série'), findsOneWidget);
    });

    testWidgets('the inbox card counts the volumes and opens the inbox', (
      tester,
    ) async {
      await pumpShelf(
        tester,
        filled(),
        routes: {AppRoutes.booksInbox: (_) => const Text('Page à classer')},
      );

      expect(find.text('À classer (2)'), findsOneWidget);
      expect(find.text('2 tomes attendent leur série'), findsOneWidget);

      await tester.tap(find.text('À classer (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Page à classer'), findsOneWidget);
    });

    testWidgets('no inbox card when everything is sorted', (tester) async {
      await pumpShelf(
        tester,
        RecordingBookshelfRepository(
          series: [_series('s1', 'Naruto')],
          volumes: [_volume('a', seriesId: 's1', number: 1)],
        ),
      );

      expect(find.textContaining('À classer'), findsNothing);
    });
  });

  group('search', () {
    testWidgets('filters while typing, and the cross clears it', (
      tester,
    ) async {
      await pumpShelf(tester, filled());

      await tester.enterText(find.byType(TextField), 'ASTE');
      await tester.pumpAndSettle();

      expect(find.byType(SeriesTile), findsOneWidget);
      expect(find.text('Astérix'), findsWidgets);
      expect(find.text('Naruto'), findsNothing);
      // Pendant la recherche, la carte « À classer » s'efface.
      expect(find.textContaining('À classer'), findsNothing);

      await tester.tap(find.byTooltip('Effacer la recherche'));
      await tester.pumpAndSettle();

      expect(find.byType(SeriesTile), findsNWidgets(3));
      expect(find.text('À classer (2)'), findsOneWidget);
      expect(find.byTooltip('Effacer la recherche'), findsNothing);
    });

    testWidgets('says when nothing matches', (tester) async {
      await pumpShelf(tester, filled());

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('Aucune série pour « zzz »'), findsOneWidget);
      expect(find.byType(SeriesTile), findsNothing);
    });
  });

  group('offline', () {
    testWidgets('shows the banner after the grace period only', (tester) async {
      final repository = filled()..offline = true;
      await tester.pumpHarness(
        const ShelfScreen(),
        overrides: overrides(repository),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(OfflineBanner), findsNothing);

      await tester.pump(ShelfOffline.grace);
      await tester.pump();
      expect(find.byType(OfflineBanner), findsOneWidget);

      repository.offline = false;
      await tester.pump();
      await tester.pump();
      expect(find.byType(OfflineBanner), findsNothing);
    });
  });

  group('behaviour', () {
    testWidgets('opening the shelf imports the legacy books', (tester) async {
      final repository = RecordingBookshelfRepository(
        legacyBooks: const [
          LegacyBook(
            id: 'k1',
            title: 'Dune',
            authors: [],
            isbn: '9780441172719',
          ),
        ],
      );
      await pumpShelf(tester, repository);

      expect(repository.importedPlans, isNotEmpty);
    });

    testWidgets('announces a write that fails later', (tester) async {
      final repository = RecordingBookshelfRepository(
        series: [_series('s1', 'Naruto')],
        volumes: [_volume('a', seriesId: 's1', number: 1)],
        failure: ShelfFailure.denied,
      );
      await pumpShelf(tester, repository);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ShelfScreen)),
      );
      await container.read(shelfEditorProvider.notifier).removeVolume('a');
      await tester.pump();

      expect(
        find.text(
          "La modification n'a pas pu être enregistrée. "
          'Vérifiez votre connexion et réessayez.',
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });
  });

  group('write errors', () {
    testWidgets('a new error replaces the one on screen', (tester) async {
      final repository = RecordingBookshelfRepository(
        series: [_series('s1', 'Naruto')],
        volumes: [_volume('a', seriesId: 's1', number: 1)],
        failure: ShelfFailure.denied,
      );
      await pumpShelf(tester, repository);
      final editor = ProviderScope.containerOf(
        tester.element(find.byType(ShelfScreen)),
      ).read(shelfEditorProvider.notifier);

      await editor.removeVolume('a');
      await tester.pump();
      await editor.removeVolume('a');
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SnackBar), findsOneWidget);

      // Remplacée, non mise en file : plus rien une fois la durée écoulée.
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('accessibility', () {
    testWidgets('meets the tap target and label guidelines', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpShelf(tester, filled());

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('holds at 200 % text without overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpShelf(tester, filled());

      expect(tester.takeException(), isNull);
      expect(find.text('Astérix'), findsOneWidget);
    });
  });
}
