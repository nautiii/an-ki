import 'package:an_ki/features/settings/widgets/settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  testWidgets('titles its rows, announced as a header', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(
      const SettingsSection(
        title: 'Préférences',
        children: [Text('Thème'), Text('Langue')],
      ),
    );

    expect(
      tester.getSemantics(find.text('Préférences')),
      isSemantics(label: 'Préférences', isHeader: true),
    );
    expect(find.text('Thème'), findsOneWidget);
    expect(find.text('Langue'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('separates the rows with one hairline each', (tester) async {
    await tester.pumpHarness(
      const SettingsSection(
        title: 'Compte',
        children: [Text('A'), Text('B'), Text('C')],
      ),
    );

    expect(find.byType(Divider), findsNWidgets(2));
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('C')),
      findsOneWidget,
    );
  });

  testWidgets('a single row has no hairline', (tester) async {
    await tester.pumpHarness(
      const SettingsSection(title: 'Profil', children: [Text('Pseudo')]),
    );

    expect(find.byType(Divider), findsNothing);
  });
}
