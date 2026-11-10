import 'package:an_ki/features/books/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  testWidgets('says it is offline without blocking anything', (tester) async {
    await tester.pumpHarness(const OfflineBanner());

    expect(find.text('Hors ligne · dates non actualisées'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
  });

  testWidgets('is announced as a live region', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(const OfflineBanner());

    expect(
      tester.getSemantics(find.text('Hors ligne · dates non actualisées')),
      isNotNull,
    );
    expect(
      find.bySemanticsLabel('Hors ligne · dates non actualisées'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
