import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/book_scanner/domain/book.dart';
import 'package:an_ki/features/book_scanner/domain/book_failure.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:an_ki/features/book_scanner/screens/book_scanner_screen.dart';
import 'package:an_ki/features/book_scanner/widgets/book_info_sheet.dart';
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

Book _book({String id = '1', String? imageUrl}) => Book(
  id: id,
  isbn: _isbn,
  title: '1984',
  authors: const ['George Orwell'],
  description: 'Big Brother is watching you.',
  imageUrl: imageUrl,
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
      AsyncValue<List<Book>> books,
    ) => tester.pumpHarness(
      const BookScannerScreen(),
      overrides: [
        savedBooksProvider.overrideWithValue(books),
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
          savedBooksProvider.overrideWithValue(const AsyncData([])),
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
      await pumpScreen(tester, AsyncData([_book()]));
      await tester.pumpAndSettle();

      expect(find.text('1984'), findsOneWidget);
      // Le carrousel garde sa hauteur au lieu de s'étirer sur l'onglet.
      expect(tester.getSize(find.byType(PageView)).height, 180);
    });

    testWidgets('grows the carousel with large text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpScreen(tester, AsyncData([_book()]));
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
          savedBooksProvider.overrideWithValue(AsyncData([_book()])),
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
      await pumpScreen(tester, AsyncData([_book()]));
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
      RecordingBookRepository repo,
    ) => tester.pumpHarness(
      const BookScannerScreen(),
      overrides: [
        bookRepositoryProvider.overrideWithValue(repo),
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
      final repo = RecordingBookRepository(bookByIsbn: _book());
      await pumpScreen(tester, repo);
      await tester.pump();

      detect(tester, _isbn);
      await settleScan(tester);

      expect(find.byType(BookInfoSheet), findsOneWidget);
      expect(platform.stopCalls, greaterThan(0));

      await tester.tap(find.text('Ajouter'));
      await settleScan(tester);

      expect(repo.saved.single.title, '1984');
      expect(find.byType(BookInfoSheet), findsNothing);
    });

    testWidgets('closing the sheet without adding resumes scanning', (
      tester,
    ) async {
      final repo = RecordingBookRepository(bookByIsbn: _book());
      await pumpScreen(tester, repo);
      await tester.pump();
      final startsBefore = platform.startCalls;

      detect(tester, _isbn);
      await settleScan(tester);
      expect(find.byType(BookInfoSheet), findsOneWidget);

      // Toucher hors de la feuille la ferme sans rien ajouter.
      await tester.tapAt(const Offset(400, 20));
      await settleScan(tester);

      expect(find.byType(BookInfoSheet), findsNothing);
      expect(repo.saved, isEmpty);
      expect(platform.startCalls, greaterThan(startsBefore));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a failed save is announced by the screen', (tester) async {
      final repo = RecordingBookRepository(
        bookByIsbn: _book(),
        failure: Exception('denied'),
      );
      await pumpScreen(tester, repo);
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
      final repo = RecordingBookRepository(bookByIsbn: _book());
      await pumpScreen(tester, repo);
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
      await pumpScreen(tester, RecordingBookRepository());
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
        RecordingBookRepository(throwOnScan: Exception('boom')),
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
        RecordingBookRepository(throwOnScan: BookFailure.network),
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
        RecordingBookRepository(throwOnScan: BookFailure.quotaExceeded),
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
