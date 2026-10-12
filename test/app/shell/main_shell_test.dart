import 'package:an_ki/app/shell/main_shell.dart';
import 'package:an_ki/core/common/bottom_bar.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/birthday/widgets/birthday_calendar.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/book_scanner/screens/book_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_mobile_scanner_platform.dart';
import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';

void main() {
  setUp(FakeMobileScannerPlatform.install);

  Finder barIcon(IconData icon) =>
      find.descendant(of: find.byType(BottomBar), matching: find.byIcon(icon));

  /// L'app connectée, ouverte sur l'onglet des anniversaires, avec un
  /// anniversaire au carnet.
  Future<void> pumpSignedIn(WidgetTester tester) async {
    await tester.pumpApp(
      auth: FakeAuthRepository(user: MockUser()),
      birthdays: [
        Birthday(
          id: '1',
          name: 'Léa',
          surname: 'Martin',
          date: DateTime(1990, 3, 12),
        ),
      ],
    );
    await tester.settleApp();
  }

  testWidgets('opens on the birthdays tab and switches to the scanner', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pumpSignedIn(tester);

      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.appRouter.state.matchedLocation, AppRoutes.birthdays);

      await tester.tap(barIcon(Icons.qr_code_scanner_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(BookScannerScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(tester.appRouter.state.matchedLocation, AppRoutes.scanner);
    });
  });

  testWidgets('a sheet covers the floating bar instead of opening under it', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pumpSignedIn(tester);

      await tester.tap(find.byTooltip('Ajouter un anniversaire'));
      await tester.pumpAndSettle();
      expect(find.byType(BirthdayFormSheet), findsOneWidget);

      // Rien de la barre ne reçoit plus les touchers : la feuille et son voile
      // passent devant.
      final bar = tester.renderObject(find.byType(BottomBar));
      final hits = tester
          .hitTestOnBinding(tester.getCenter(find.byType(BottomBar)))
          .path
          .map((entry) => entry.target);
      expect(hits, isNot(contains(bar)));
    });
  });

  testWidgets('a snackbar from a tab floats above the nav bar', (tester) async {
    await mockNetworkImages(() async {
      await pumpSignedIn(tester);

      ScaffoldMessenger.of(tester.element(find.byType(HomeScreen)))
          .showSnackBar(const SnackBar(content: Text('Hello')));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byType(SnackBar)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(BottomBar)).top),
      );

      // Laisse la snackbar se fermer : aucun minuteur en attente.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('a hidden tab stays mounted with its state', (tester) async {
    await mockNetworkImages(() async {
      await pumpSignedIn(tester);
      await tester.tap(find.text('Calendrier'));
      await tester.pumpAndSettle();
      expect(find.byType(BirthdayCalendar), findsOneWidget);

      await tester.tap(barIcon(Icons.qr_code_scanner_rounded));
      await tester.pumpAndSettle();
      // Caché, l'onglet des anniversaires n'est pas démonté.
      expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);

      await tester.tap(barIcon(Icons.cake_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(BirthdayCalendar), findsOneWidget);
    });
  });

  testWidgets('switches at once when animations are disabled', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await mockNetworkImages(() async {
      await pumpSignedIn(tester);

      await tester.tap(barIcon(Icons.qr_code_scanner_rounded));
      await tester.pump();

      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(BookScannerScreen),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}
