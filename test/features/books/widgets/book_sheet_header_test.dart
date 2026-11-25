import 'package:an_ki/features/books/widgets/book_sheet_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  testWidgets('shows the title as a heading, then its explanation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(
      const BookSheetHeader(
        leading: BookSheetIcon(icon: Icons.keyboard_rounded),
        title: 'Saisir un ISBN',
        subtitle: '10 ou 13 chiffres',
      ),
    );

    expect(find.text('10 ou 13 chiffres'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Saisir un ISBN')),
      isSemantics(label: 'Saisir un ISBN', isHeader: true),
    );
    // L'icône est décorative.
    expect(
      find.descendant(
        of: find.byType(BookSheetIcon),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    semantics.dispose();
  });

  testWidgets('holds a long title at 200 % text on a narrow screen', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpHarness(
      const SingleChildScrollView(
        child: BookSheetHeader(
          leading: BookSheetIcon(icon: Icons.event_rounded),
          title: 'Sortie du tome 109',
          subtitle: "Vue sur une affiche ou le site de l'éditeur, par exemple.",
        ),
      ),
    );
    // Après le harnais, qui pose son propre écran de 800 × 1200.
    tester.view
      ..physicalSize = const Size(360, 640)
      ..devicePixelRatio = 1;
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BookSheetHeader)).width, 360);
  });
}
