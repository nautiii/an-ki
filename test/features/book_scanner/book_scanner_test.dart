import 'package:an_ki/features/book_scanner/screens/book_scanner_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import '../../support/fake_providers.dart';

void main() {
  testWidgets('BookScannerScreen shows scanner title', (tester) async {
    await tester.pumpHarness(
      const BookScannerScreen(),
      overrides: defaultTestOverrides,
    );
    await tester.pumpAndSettle();

    expect(find.text('Scanner de livres'), findsOneWidget);
  });
}
