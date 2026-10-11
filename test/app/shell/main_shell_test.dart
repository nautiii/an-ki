import 'package:an_ki/app/shell/main_shell.dart';
import 'package:an_ki/core/common/bottom_bar.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
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

  /// L'app connectée, ouverte sur l'onglet des anniversaires.
  Future<void> pumpSignedIn(WidgetTester tester) async {
    await tester.pumpApp(auth: FakeAuthRepository(user: MockUser()));
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

  testWidgets('a hidden tab stays mounted with its state', (tester) async {
    await mockNetworkImages(() async {
      await pumpSignedIn(tester);
      await tester.enterText(find.byType(TextField).first, 'Lé');
      await tester.pumpAndSettle();

      await tester.tap(barIcon(Icons.qr_code_scanner_rounded));
      await tester.pumpAndSettle();
      // Caché, l'onglet des anniversaires n'est pas démonté.
      expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);

      await tester.tap(barIcon(Icons.cake_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Lé'), findsOneWidget);
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
