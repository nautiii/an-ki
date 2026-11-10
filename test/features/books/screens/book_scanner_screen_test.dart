import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/providers/volume_lookup.dart';
import 'package:an_ki/features/books/screens/book_scanner_screen.dart';
import 'package:an_ki/features/books/widgets/book_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../support/fake_mobile_scanner_platform.dart';
import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

/// ISBN-13 lu sur un code-barres de livre.
const _isbn = '9780451524935';

/// Ce que les catalogues savent de « 1984 ».
IdentifiedVolume _identified(String isbn) => IdentifiedVolume(
  isbn: isbn,
  metadata: const BookMetadata(title: '1984', authors: ['George Orwell']),
);

void main() {
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

    testWidgets('shows its title and the hint', (tester) async {
      await pumpScreen(
        tester,
        RecordingBookshelfRepository(),
        RecordingVolumeLookup(),
      );
      await tester.pump();

      expect(find.text('Scanner un livre'), findsOneWidget);
    });

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

  group('BookScannerScreen camera errors', () {
    Future<FakeContactsService> pumpWithError(
      WidgetTester tester,
      FakeMobileScannerPlatform platform,
    ) async {
      final contacts = FakeContactsService();
      await tester.pumpHarness(
        const BookScannerScreen(),
        overrides: [
          bookshelfRepositoryProvider.overrideWithValue(
            RecordingBookshelfRepository(),
          ),
          currentUidProvider.overrideWithValue('fake-uid'),
          contactsServiceProvider.overrideWithValue(contacts),
        ],
      );
      await tester.pump();
      await tester.pump();
      return contacts;
    }

    testWidgets('a refused permission shows our own copy', (tester) async {
      final platform = FakeMobileScannerPlatform.install(
        startError: MobileScannerErrorCode.permissionDenied,
      );
      await pumpWithError(tester, platform);

      expect(find.text("AnKi n'a pas accès à la caméra"), findsOneWidget);
      expect(find.text('Camera permission denied.'), findsNothing);
      expect(find.text('Autoriser la caméra'), findsOneWidget);
      expect(find.text('Ouvrir les réglages'), findsOneWidget);
    });

    testWidgets('"Autoriser la caméra" starts the camera again', (
      tester,
    ) async {
      final platform = FakeMobileScannerPlatform.install(
        startError: MobileScannerErrorCode.permissionDenied,
      );
      await pumpWithError(tester, platform);
      final startsBefore = platform.startCalls;

      await tester.tap(find.text('Autoriser la caméra'));
      await tester.pump();

      expect(platform.startCalls, greaterThan(startsBefore));
    });

    testWidgets('"Ouvrir les réglages" opens the app settings', (tester) async {
      final platform = FakeMobileScannerPlatform.install(
        startError: MobileScannerErrorCode.permissionDenied,
      );
      final contacts = await pumpWithError(tester, platform);

      await tester.tap(find.text('Ouvrir les réglages'));
      await tester.pump();

      expect(contacts.settingsOpened, 1);
    });

    testWidgets(
      'touching "Autoriser la caméra" twice in a row throws nothing',
      (tester) async {
        final platform = FakeMobileScannerPlatform.install(
          startError: MobileScannerErrorCode.permissionDenied,
        );
        await pumpWithError(tester, platform);

        await tester.tap(find.text('Autoriser la caméra'));
        await tester.tap(find.text('Autoriser la caméra'));
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('touching "Réessayer" twice in a row throws nothing', (
      tester,
    ) async {
      final other = FakeMobileScannerPlatform.install(
        startError: MobileScannerErrorCode.genericError,
      );
      await pumpWithError(tester, other);
      await tester.tap(find.text('Réessayer'));
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('on resume with the permission denied, starts again', (
      tester,
    ) async {
      final platform = FakeMobileScannerPlatform.install(
        startError: MobileScannerErrorCode.permissionDenied,
      );
      await pumpWithError(tester, platform);
      final startsBefore = platform.startCalls;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(platform.startCalls, greaterThan(startsBefore));
      expect(tester.takeException(), isNull);
    });

    testWidgets('on resume with another error, does not start again', (
      tester,
    ) async {
      final platform = FakeMobileScannerPlatform.install(
        startError: MobileScannerErrorCode.genericError,
      );
      await pumpWithError(tester, platform);
      final startsBefore = platform.startCalls;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(platform.startCalls, startsBefore);
    });

    testWidgets('another start error says the camera is unavailable', (
      tester,
    ) async {
      final platform = FakeMobileScannerPlatform.install(
        startError: MobileScannerErrorCode.genericError,
      );
      await pumpWithError(tester, platform);

      expect(find.text('Caméra indisponible'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Ouvrir les réglages'), findsNothing);

      final startsBefore = platform.startCalls;
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      expect(platform.startCalls, greaterThan(startsBefore));
    });
  });
}
