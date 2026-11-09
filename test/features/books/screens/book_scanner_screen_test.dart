import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/providers/book_scanner_provider.dart';
import 'package:an_ki/features/books/providers/legacy_import.dart';
import 'package:an_ki/features/books/providers/volume_lookup.dart';
import 'package:an_ki/features/books/screens/book_scanner_screen.dart';
import 'package:an_ki/features/books/widgets/book_info_sheet.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../support/fake_mobile_scanner_platform.dart';
import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

/// ISBN-13 lu sur un code-barres de livre.
const _isbn = '9780451524935';

Volume _volume({String id = '1', String? imageUrl}) => Volume(
  id: id,
  isbn: _isbn,
  title: '1984',
  authors: const ['George Orwell'],
  imageUrl: imageUrl,
  lookup: LookupState.found,
  addedAt: DateTime(2026, 11, 9),
);

/// Ce que les catalogues savent de « 1984 ».
IdentifiedVolume _identified(String isbn) => IdentifiedVolume(
  isbn: isbn,
  metadata: const BookMetadata(title: '1984', authors: ['George Orwell']),
);

/// Profil chargé : la barre salue par le prénom.
const _profile = UserProfile(
  id: 'fake-uid',
  name: 'Camille',
  surname: 'Durand',
  locale: 'fr',
);

void main() {
  group('BookScannerScreen rendering', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      AsyncValue<List<Volume>> volumes,
    ) => tester.pumpHarness(
      const BookScannerScreen(),
      overrides: [
        scannedVolumesProvider.overrideWithValue(volumes),
        legacyImportProvider.overrideWithValue(const AsyncData(null)),
        userProfileProvider.overrideWithValue(const AsyncData(_profile)),
      ],
    );

    testWidgets('shows the title and empty state', (tester) async {
      await pumpScreen(tester, const AsyncData([]));
      await tester.pumpAndSettle();

      expect(find.text('Scanner de livres'), findsOneWidget);
      expect(find.text("Aucun livre pour l'instant"), findsOneWidget);
      // Pas de puces qui auraient l'air de filtrer sans rien filtrer.
      expect(find.byType(Chip), findsNothing);
      expect(
        find.text(
          "Scannez le code-barres d'un livre pour garder une idée de cadeau.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows a skeleton while loading', (tester) async {
      await pumpScreen(tester, const AsyncLoading());
      await tester.pump();

      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.text("Aucun livre pour l'instant"), findsNothing);
    });

    testWidgets('the settings button opens the settings route', (tester) async {
      await tester.pumpHarness(
        const BookScannerScreen(),
        overrides: [
          scannedVolumesProvider.overrideWithValue(const AsyncData([])),
          legacyImportProvider.overrideWithValue(const AsyncData(null)),
          userProfileProvider.overrideWithValue(const AsyncData(_profile)),
        ],
        routes: {AppRoutes.settings: (_) => const Text('Settings route')},
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Paramètres'));
      await tester.pumpAndSettle();

      expect(find.text('Settings route'), findsOneWidget);
    });

    testWidgets('greets in a pinned app bar, like the home', (tester) async {
      await pumpScreen(tester, const AsyncData([]));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.textContaining('Camille'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays saved books in a carousel', (tester) async {
      await pumpScreen(tester, AsyncData([_volume()]));
      await tester.pumpAndSettle();

      expect(find.text('1984'), findsOneWidget);
      // Le carrousel garde sa hauteur au lieu de s'étirer sur l'onglet.
      expect(tester.getSize(find.byType(PageView)).height, 180);
    });

    testWidgets('grows the carousel with large text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpScreen(tester, AsyncData([_volume()]));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(PageView)).height, 360);
    });

    testWidgets('grows the carousel with Android 14 non-linear scaling', (
      tester,
    ) async {
      await tester.pumpHarness(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const _NonLinearScaler()),
            child: const BookScannerScreen(),
          ),
        ),
        overrides: [
          scannedVolumesProvider.overrideWithValue(AsyncData([_volume()])),
          legacyImportProvider.overrideWithValue(const AsyncData(null)),
          userProfileProvider.overrideWithValue(const AsyncData(_profile)),
        ],
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(PageView)).height, 360);
    });

    testWidgets('scrolls to a whole card on a compact phone at 200 %', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpScreen(tester, AsyncData([_volume()]));
      await tester.pumpAndSettle();

      // Aucun débordement, et la carte garde toute sa hauteur.
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(PageView)).height, 360);
    });

    testWidgets('labels and sizes its app bar buttons', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester, const AsyncData([]));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });

  group('BookScannerScreen scan flow (real providers + fake camera)', () {
    late FakeMobileScannerPlatform platform;

    setUp(() => platform = FakeMobileScannerPlatform.install());

    Future<void> pumpScreen(
      WidgetTester tester,
      RecordingBookshelfRepository repo,
      RecordingVolumeLookup lookup,
    ) => tester.pumpHarness(
      const BookScannerScreen(),
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repo),
        volumeLookupProvider.overrideWithValue(lookup),
        currentUidProvider.overrideWithValue('fake-uid'),
        userProfileProvider.overrideWithValue(const AsyncData(_profile)),
      ],
    );

    void detect(WidgetTester tester, String isbn) {
      final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      scanner.onDetect!(BarcodeCapture(barcodes: [Barcode(rawValue: isbn)]));
    }

    // Pas de pumpAndSettle : le scanner garde un voile animé pendant le
    // traitement.
    Future<void> settleScan(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('a successful scan opens the sheet and saves the book', (
      tester,
    ) async {
      final repo = RecordingBookshelfRepository();
      final lookup = RecordingVolumeLookup(found: _identified);
      await pumpScreen(tester, repo, lookup);
      await tester.pump();

      // La caméra relit le code tant qu'il est devant elle : une seule fiche.
      detect(tester, _isbn);
      detect(tester, _isbn);
      await settleScan(tester);

      expect(find.byType(BookInfoSheet), findsOneWidget);
      expect(platform.stopCalls, greaterThan(0));

      await tester.tap(find.text('Ajouter'));
      await settleScan(tester);

      expect(repo.volumes.single.title, '1984');
      // « Ajouter » ne relance pas la recherche : la fiche porte déjà le livre.
      expect(lookup.lookedUp, [_isbn]);
      expect(find.byType(BookInfoSheet), findsNothing);
    });

    testWidgets('the carousel shows a volume added through the sheet', (
      tester,
    ) async {
      final repo = RecordingBookshelfRepository();
      await pumpScreen(tester, repo, RecordingVolumeLookup(found: _identified));
      await tester.pump();
      expect(find.byType(PageView), findsNothing);

      detect(tester, _isbn);
      await settleScan(tester);
      await tester.tap(find.text('Ajouter'));
      await settleScan(tester);

      expect(find.byType(BookInfoSheet), findsNothing);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('1984'), findsOneWidget);
    });

    testWidgets('closing the sheet without adding resumes scanning', (
      tester,
    ) async {
      final repo = RecordingBookshelfRepository();
      await pumpScreen(tester, repo, RecordingVolumeLookup(found: _identified));
      await tester.pump();
      final startsBefore = platform.startCalls;

      detect(tester, _isbn);
      await settleScan(tester);
      expect(find.byType(BookInfoSheet), findsOneWidget);

      // Toucher hors de la feuille la ferme sans rien ajouter.
      await tester.tapAt(const Offset(400, 20));
      await settleScan(tester);

      expect(find.byType(BookInfoSheet), findsNothing);
      expect(repo.savedVolumes, isEmpty);
      expect(platform.startCalls, greaterThan(startsBefore));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a failed save is announced by the screen', (tester) async {
      final repo = RecordingBookshelfRepository(failure: Exception('denied'));
      await pumpScreen(tester, repo, RecordingVolumeLookup(found: _identified));
      await tester.pump();

      detect(tester, _isbn);
      await settleScan(tester);
      await tester.tap(find.text('Ajouter'));
      await settleScan(tester);

      expect(
        find.text("Quelque chose s'est mal passé. Réessayez dans un instant."),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('ignores a code that is not a book ISBN', (tester) async {
      final repo = RecordingBookshelfRepository();
      await pumpScreen(tester, repo, RecordingVolumeLookup(found: _identified));
      await tester.pump();
      final stopsBefore = platform.stopCalls;

      // Un QR code, puis le code-barres d'un produit (EAN-13 sans 978/979).
      detect(tester, 'https://example.com/?q=1%');
      detect(tester, '3017620422003');
      await settleScan(tester);

      expect(find.byType(BookInfoSheet), findsNothing);
      expect(platform.stopCalls, stopsBefore);
    });

    testWidgets('an unknown ISBN shows the "not found" message', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        RecordingBookshelfRepository(),
        RecordingVolumeLookup(),
      );
      await tester.pump();

      detect(tester, _isbn);
      await settleScan(tester);

      expect(find.text('Livre non trouvé'), findsOneWidget);
      // Vide le minuteur du SnackBar et la relance de la caméra.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a generic error shows the unknown error message', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        RecordingBookshelfRepository(),
        RecordingVolumeLookup(failure: Exception('boom')),
      );
      await tester.pump();

      detect(tester, _isbn);
      await settleScan(tester);

      expect(
        find.text("Quelque chose s'est mal passé. Réessayez dans un instant."),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a network error asks to check the connection', (tester) async {
      await pumpScreen(
        tester,
        RecordingBookshelfRepository(),
        RecordingVolumeLookup(failure: BookFailure.network),
      );
      await tester.pump();

      detect(tester, _isbn);
      await settleScan(tester);

      expect(
        find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a quota error shows the dedicated message', (tester) async {
      await pumpScreen(
        tester,
        RecordingBookshelfRepository(),
        RecordingVolumeLookup(failure: BookFailure.quotaExceeded),
      );
      await tester.pump();

      detect(tester, _isbn);
      await settleScan(tester);

      expect(
        find.text(
          'Limite de recherche atteinte. Veuillez réessayer plus tard.',
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });
}

/// Grand texte à la manière d'Android 14+ : le petit texte double, le grand
/// grandit à peine.
class _NonLinearScaler extends TextScaler {
  const _NonLinearScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 24 ? fontSize * 2 : fontSize + 24;

  @override
  double get textScaleFactor => 2;

  @override
  TextScaler clamp({double minScaleFactor = 0, double maxScaleFactor = 2}) =>
      this;
}
