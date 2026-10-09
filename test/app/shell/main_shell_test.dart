import 'package:an_ki/app/shell/main_shell.dart';
import 'package:an_ki/core/common/bottom_bar.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/book_scanner/screens/book_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_mobile_scanner_platform.dart';
import '../../support/network_image_mock.dart';
import '../../support/test_harness.dart';

void main() {
  setUp(FakeMobileScannerPlatform.install);

  Finder barLabel(String label) =>
      find.descendant(of: find.byType(BottomBar), matching: find.text(label));

  testWidgets('opens on the birthdays tab and switches to the scanner', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(const MainShell());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(barLabel('Anniversaires'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(BottomBar),
          matching: find.byIcon(Icons.qr_code_scanner_rounded),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BookScannerScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(barLabel('Scanner'), findsOneWidget);
    });
  });
}
