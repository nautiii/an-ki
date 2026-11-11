import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_guess.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/providers/volume_lookup.dart';
import 'package:an_ki/features/books/screens/book_scanner_screen.dart';
import 'package:an_ki/features/books/widgets/classify_sheet.dart';
import 'package:an_ki/features/books/widgets/volume_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../support/fake_mobile_scanner_platform.dart';
import '../../../support/fake_providers.dart';
import '../../../support/haptics.dart';
import '../../../support/test_harness.dart';

/// ISBN-13 valides (clé de contrôle juste).
const _isbn = '9782344059562';
const _other = '9782723488525';

IdentifiedVolume _onePiece(String isbn) => IdentifiedVolume(
  isbn: isbn,
  metadata: const BookMetadata(title: 'One Piece', authors: ['Eiichirō Oda']),
  guess: VolumeGuess(
    seriesName: 'One Piece',
    number: isbn == _isbn ? 108 : 109,
    confidence: GuessConfidence.high,
  ),
);

const _series = Series(
  id: 's1',
  name: 'One Piece',
  keys: ['one piece'],
  complete: false,
);

final _owned = Volume(
  id: _isbn,
  seriesId: 's1',
  number: 107,
  isbn: _isbn,
  title: 'One Piece',
  authors: const [],
  lookup: LookupState.found,
  addedAt: DateTime(2026, 11, 2),
);

void main() {
  group('BookScannerScreen burst (real providers + fake camera)', () {
    late FakeMobileScannerPlatform platform;

    setUp(() => platform = FakeMobileScannerPlatform.install());

    Future<void> pumpScreen(
      WidgetTester tester, {
      RecordingBookshelfRepository? repo,
      VolumeLookup? lookup,
    }) async {
      await tester.pumpHarness(
        const BookScannerScreen(),
        overrides: [
          bookshelfRepositoryProvider.overrideWithValue(
            repo ?? RecordingBookshelfRepository(),
          ),
          volumeLookupProvider.overrideWithValue(
            lookup ?? RecordingVolumeLookup(found: _onePiece),
          ),
          currentUidProvider.overrideWithValue('fake-uid'),
        ],
      );
      await tester.pump();
    }

    void detect(WidgetTester tester, String code) {
      final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      scanner.onDetect!(BarcodeCapture(barcodes: [Barcode(rawValue: code)]));
    }

    // Laisse les écritures et la recherche se faire, et la coche s'animer.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('shows its title, the hint and the two fallbacks', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Scanner un livre'), findsOneWidget);
      expect(find.text('Visez le code-barres au dos du livre'), findsOneWidget);
      expect(find.text('Saisir un ISBN'), findsOneWidget);
      expect(find.text('Terminé'), findsOneWidget);
    });

    testWidgets('the camera keeps running and each volume stacks, newest '
        'first, with one light vibration each', (tester) async {
      final haptics = recordHaptics(tester);
      final repo = RecordingBookshelfRepository();
      await pumpScreen(tester, repo: repo);

      detect(tester, _isbn);
      // La caméra relit le même code tant qu'il reste devant elle.
      detect(tester, _isbn);
      await settle(tester);
      detect(tester, _other);
      await settle(tester);

      expect(platform.stopCalls, 0);
      expect(find.text('One Piece · tome 109'), findsOneWidget);
      expect(find.text('One Piece · tome 108'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('One Piece · tome 109')).dy,
        lessThan(tester.getTopLeft(find.text('One Piece · tome 108')).dy),
      );
      expect(find.text('2 tomes ajoutés'), findsOneWidget);
      expect(haptics, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.lightImpact',
      ]);
      expect(repo.volumes, hasLength(2));
    });

    testWidgets('a row pushed down by a new one keeps its check, no replay', (
      tester,
    ) async {
      await pumpScreen(tester);
      detect(tester, _isbn);
      await settle(tester);

      // La coche d'une ligne : l'état de son animation.
      State checkOf(String text) => tester.state(
        find.descendant(
          of: find.ancestor(
            of: find.text(text),
            matching: find.byType(ListTile),
          ),
          matching: find.byType(TweenAnimationBuilder<double>),
        ),
      );
      final before = checkOf('One Piece · tome 108');

      detect(tester, _other);
      await settle(tester);

      // La ligne a descendu d'un cran sans être recréée : sa coche ne
      // repart pas de zéro.
      expect(find.text('One Piece · tome 109'), findsOneWidget);
      expect(checkOf('One Piece · tome 108'), same(before));
    });

    testWidgets('a volume already owned says so, without vibrating', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      final repo = RecordingBookshelfRepository(
        series: [_series],
        volumes: [_owned],
      );
      await pumpScreen(tester, repo: repo);
      await settle(tester);

      detect(tester, _isbn);
      await settle(tester);

      expect(
        find.text('Déjà dans votre collection · One Piece 107'),
        findsOneWidget,
      );
      expect(haptics, isEmpty);
      expect(repo.savedVolumes, isEmpty);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('owned volumes in a row show one short notice, never hiding '
        'an undo', (tester) async {
      const third = '9782205046090';
      Volume owned(String isbn) => Volume(
        id: isbn,
        seriesId: 's1',
        number: 100,
        isbn: isbn,
        title: 'One Piece',
        authors: const [],
        lookup: LookupState.found,
        addedAt: DateTime(2026, 11, 2),
      );
      await pumpScreen(
        tester,
        repo: RecordingBookshelfRepository(
          series: [_series],
          volumes: [owned(_isbn), owned(_other), owned(third)],
        ),
      );
      await settle(tester);
      // Un « Annuler » déjà affiché (un retrait fait dans la rafale).
      ScaffoldMessenger.of(tester.element(find.byType(BookScannerScreen)))
          .showSnackBar(
            SnackBar(
              persist: false,
              content: const Text('Tome retiré'),
              action: SnackBarAction(label: 'Annuler', onPressed: () {}),
            ),
          );
      await tester.pump();

      detect(tester, _isbn);
      detect(tester, _other);
      detect(tester, third);
      await tester.pump();

      // L'« Annuler » reste ; un seul message attend derrière lui.
      expect(find.text('Annuler'), findsOneWidget);
      // L'« Annuler » finit d'entrer, expire (4 s), puis le message passe.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.textContaining('Déjà dans votre collection'), findsOneWidget);
      // Bref (2 s), et rien d'autre en file.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a code that is not a book ISBN is ignored', (tester) async {
      final haptics = recordHaptics(tester);
      final repo = RecordingBookshelfRepository();
      await pumpScreen(tester, repo: repo);

      // Un QR code, puis le code-barres d'un produit (EAN-13 sans 978/979).
      detect(tester, 'https://example.com/?q=1%');
      detect(tester, '3017620422003');
      await settle(tester);

      expect(repo.savedVolumes, isEmpty);
      expect(haptics, isEmpty);
    });

    testWidgets('offline, the volume stacks as "infos à compléter"', (
      tester,
    ) async {
      final repo = RecordingBookshelfRepository();
      await pumpScreen(
        tester,
        repo: repo,
        lookup: RecordingVolumeLookup(failure: BookFailure.network),
      );

      detect(tester, _isbn);
      await settle(tester);

      expect(find.text('ISBN $_isbn · infos à compléter'), findsOneWidget);
      expect(repo.volumes.single.lookup, LookupState.pending);
    });

    testWidgets('"Introuvable · Classer" opens the classify sheet', (
      tester,
    ) async {
      await pumpScreen(tester, lookup: RecordingVolumeLookup());

      detect(tester, _isbn);
      await settle(tester);
      await tester.tap(find.text('Introuvable · Classer'));
      await tester.pumpAndSettle();

      expect(find.byType(ClassifySheet), findsOneWidget);
    });

    testWidgets('tapping an added volume opens its sheet', (tester) async {
      await pumpScreen(tester);

      detect(tester, _isbn);
      await settle(tester);
      await tester.tap(find.text('One Piece · tome 108'));
      await tester.pumpAndSettle();

      expect(find.byType(VolumeSheet), findsOneWidget);
    });

    testWidgets('a typed ISBN is checked, then added like a scan', (
      tester,
    ) async {
      final repo = RecordingBookshelfRepository();
      await pumpScreen(tester, repo: repo);

      await tester.tap(find.text('Saisir un ISBN'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '978-2-344-05956-3');
      await tester.pump();
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();
      expect(
        find.text("Cet ISBN n'existe pas : vérifiez les chiffres"),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '978-2-344-05956-2');
      await tester.pump();
      await tester.tap(find.text('Ajouter'));
      await settle(tester);
      await tester.pumpAndSettle();

      expect(find.text('One Piece · tome 108'), findsOneWidget);
      expect(repo.volumes.single.id, _isbn);
    });

    testWidgets('the torch button toggles the torch', (tester) async {
      await pumpScreen(tester);
      await tester.pump();

      expect(find.byTooltip('Allumer la lampe'), findsOneWidget);
      await tester.tap(find.byTooltip('Allumer la lampe'));
      await tester.pump();
      expect(platform.torchToggles, 1);
    });

    testWidgets('"Terminé" goes back to the shelf', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Terminé'));
      await tester.pumpAndSettle();

      expect(find.byType(BookScannerScreen), findsNothing);
    });

    testWidgets('targets are large and labelled, with a burst list', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);
      detect(tester, _isbn);
      await settle(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('with reduced motion, the check appears without animating', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpScreen(tester);

      detect(tester, _isbn);
      await settle(tester);

      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
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
