import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  testWidgets('shows its message and triggers both actions', (tester) async {
    var added = 0;
    var imported = 0;
    await tester.pumpHarness(
      AnKiEmptyState(
        illustration: const Icon(Icons.nights_stay_rounded),
        title: 'Vos anniversaires vivront ici',
        message: 'AnKi vous préviendra au bon moment.',
        primaryLabel: 'Ajouter un anniversaire',
        onPrimary: () => added++,
        secondaryLabel: 'Importer mes contacts',
        onSecondary: () => imported++,
      ),
    );

    expect(find.text('Vos anniversaires vivront ici'), findsOneWidget);
    expect(find.text('AnKi vous préviendra au bon moment.'), findsOneWidget);

    await tester.tap(find.text('Ajouter un anniversaire'));
    await tester.tap(find.text('Importer mes contacts'));
    expect(added, 1);
    expect(imported, 1);
  });

  testWidgets('shows the icon of its main action and its footer', (
    tester,
  ) async {
    await tester.pumpHarness(
      AnKiEmptyState(
        illustration: const SizedBox(),
        title: 'Qui voulez-vous fêter ?',
        message: 'Retrouvez les anniversaires de vos contacts.',
        primaryLabel: 'Choisir dans mes contacts',
        primaryIcon: Icons.contacts_rounded,
        onPrimary: () {},
        footer: const Text('AnKi ne lit que les noms et les dates.'),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byIcon(Icons.contacts_rounded),
      ),
      findsOneWidget,
    );
    expect(find.text('AnKi ne lit que les noms et les dates.'), findsOneWidget);
  });

  testWidgets('renders no button without labels', (tester) async {
    await tester.pumpHarness(
      const AnKiEmptyState(
        illustration: SizedBox(),
        title: 'Aucun résultat',
        message: 'Essayez un autre nom.',
      ),
    );

    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('meets tap target and label guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(
      AnKiEmptyState(
        illustration: const Icon(Icons.nights_stay_rounded),
        title: 'Titre',
        message: 'Message',
        primaryLabel: 'Ajouter',
        onPrimary: () {},
        secondaryLabel: 'Importer',
        onSecondary: () {},
      ),
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
