import 'package:an_ki/features/books/widgets/volume_range_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  testWidgets('says how many volumes and which are missing', (tester) async {
    await tester.pumpHarness(const VolumeRangePreview(numbers: [1, 2, 3, 6]));

    expect(find.text('4 tomes'), findsOneWidget);
    expect(find.text('Il vous manque 4, 5'), findsOneWidget);
  });

  testWidgets('no holes, no missing line', (tester) async {
    await tester.pumpHarness(const VolumeRangePreview(numbers: [1]));

    expect(find.text('1 tome'), findsOneWidget);
    expect(find.textContaining('manque'), findsNothing);
  });

  testWidgets('a joined series: its volumes fill the holes, only the new '
      'ones count', (tester) async {
    await tester.pumpHarness(
      const VolumeRangePreview(
        numbers: [1, 2, 3, 4, 5, 6],
        alreadyOwned: [4, 5, 6, 7, 8],
      ),
    );

    expect(find.text('3 tomes'), findsOneWidget);
    expect(find.textContaining('manque'), findsNothing);
  });

  testWidgets('everything already owned says so', (tester) async {
    await tester.pumpHarness(
      const VolumeRangePreview(numbers: [1, 2], alreadyOwned: [1, 2, 3]),
    );

    expect(find.text('Déjà tous sur votre étagère'), findsOneWidget);
  });

  testWidgets('the spines are decorative: TalkBack never scrolls them', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(
      VolumeRangePreview(numbers: [for (var n = 1; n <= 120; n++) n]),
    );

    // Aucun nœud qui défile : le rayon n'existe pas pour TalkBack.
    final scrollable = <SemanticsNode>[];
    void visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (data.hasAction(SemanticsAction.scrollLeft) ||
          data.hasAction(SemanticsAction.scrollRight)) {
        scrollable.add(node);
      }
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(tester.getSemantics(find.byType(VolumeRangePreview)));
    expect(scrollable, isEmpty);
    semantics.dispose();
  });

  testWidgets('the longest series builds only the spines on screen', (
    tester,
  ) async {
    await tester.pumpHarness(
      VolumeRangePreview(numbers: [for (var n = 1; n <= 1000; n++) n]),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('1000 tomes'), findsOneWidget);
    expect(
      find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(DecoratedBox),
          )
          .evaluate()
          .length,
      lessThan(100),
    );
  });
}
