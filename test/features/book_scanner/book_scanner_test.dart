import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/book_scanner/domain/book.dart';
import 'package:an_ki/features/book_scanner/domain/book_failure.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:an_ki/features/book_scanner/screens/book_scanner_screen.dart';
import 'package:an_ki/features/book_scanner/widgets/book_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../support/fake_mobile_scanner_platform.dart';
import '../../support/fake_providers.dart';
import '../../support/test_harness.dart';

Book _book({String id = '1', String? imageUrl}) => Book(
  id: id,
  isbn: '987654321',
  title: '1984',
  authors: const ['George Orwell'],
  description: 'Big Brother is watching you.',
  imageUrl: imageUrl,
);

void main() {
  group('BookScannerScreen rendering', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      AsyncValue<List<Book>> books,
    ) => tester.pumpHarness(
      const BookScannerScreen(),
      overrides: [savedBooksProvider.overrideWithValue(books)],
    );

    testWidgets('shows the title and empty state', (tester) async {
      await pumpScreen(tester, const AsyncData([]));
      await tester.pumpAndSettle();

      expect(find.text('Scanner de livres'), findsOneWidget);
      expect(find.text('Aucun livre trouvé.'), findsOneWidget);
    });

    testWidgets('shows a loading indicator while loading', (tester) async {
      await pumpScreen(tester, const AsyncLoading());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('the settings button opens the settings route', (tester) async {
      await tester.pumpHarness(
        const BookScannerScreen(),
        overrides: [savedBooksProvider.overrideWithValue(const AsyncData([]))],
        routes: {AppRoutes.settings: (_) => const Text('Settings route')},
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Settings route'), findsOneWidget);
    });

    testWidgets('displays saved books in a carousel', (tester) async {
      await pumpScreen(tester, AsyncData([_book()]));
      await tester.pumpAndSettle();

      expect(find.text('1984'), findsOneWidget);
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

      detect(tester, '987654321');
      await settleScan(tester);

      expect(find.byType(BookInfoSheet), findsOneWidget);
      expect(platform.stopCalls, greaterThan(0));

      await tester.tap(find.text('Ajouter'));
      await settleScan(tester);

      expect(repo.saved.single.title, '1984');
      expect(find.byType(BookInfoSheet), findsNothing);
    });

    testWidgets('a failed save is announced by the screen', (tester) async {
      final repo = RecordingBookRepository(
        bookByIsbn: _book(),
        failure: Exception('denied'),
      );
      await pumpScreen(tester, repo);
      await tester.pump();

      detect(tester, '987654321');
      await settleScan(tester);
      await tester.tap(find.text('Ajouter'));
      await settleScan(tester);

      expect(find.text('Une erreur est survenue.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('an unknown ISBN shows the "not found" message', (
      tester,
    ) async {
      await pumpScreen(tester, RecordingBookRepository());
      await tester.pump();

      detect(tester, '000');
      await settleScan(tester);

      expect(find.text('Livre non trouvé'), findsOneWidget);
      // Vide le minuteur du SnackBar et la relance de la caméra.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a generic error shows the "not found" message', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        RecordingBookRepository(throwOnScan: Exception('boom')),
      );
      await tester.pump();

      detect(tester, '111');
      await settleScan(tester);

      expect(find.text('Livre non trouvé'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a quota error shows the dedicated message', (tester) async {
      await pumpScreen(
        tester,
        RecordingBookRepository(throwOnScan: BookFailure.quotaExceeded),
      );
      await tester.pump();

      detect(tester, '123');
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
