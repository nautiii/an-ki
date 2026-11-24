import 'package:an_ki/features/books/widgets/shelf_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  testWidgets('separates its rows with indented dividers', (tester) async {
    await tester.pumpHarness(
      const ShelfGroup(
        dividerIndent: 88,
        children: [Text('Un'), Text('Deux'), Text('Trois')],
      ),
    );

    final dividers = tester.widgetList<Divider>(find.byType(Divider));
    expect(dividers, hasLength(2));
    expect(dividers.first.indent, 88);
  });

  testWidgets('at 200 % text, the dividers start at the edge', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpHarness(
      const ShelfGroup(dividerIndent: 88, children: [Text('Un'), Text('Deux')]),
    );

    expect(tester.widget<Divider>(find.byType(Divider)).indent, 16);
  });

  testWidgets('an item of a long list rounds only the ends', (tester) async {
    await tester.pumpHarness(
      Column(
        children: [
          for (var i = 0; i < 3; i++)
            ShelfGroupItem(
              index: i,
              count: 3,
              dividerIndent: 88,
              child: Text('Ligne $i'),
            ),
        ],
      ),
    );

    BorderRadius radiusOf(int i) =>
        ((tester
                        .widget<Material>(
                          find
                              .ancestor(
                                of: find.text('Ligne $i'),
                                matching: find.byType(Material),
                              )
                              .first,
                        )
                        .shape
                    as RoundedSuperellipseBorder?)!
                .borderRadius
            as BorderRadius);

    expect(radiusOf(0).topLeft, const Radius.circular(24));
    expect(radiusOf(0).bottomLeft, Radius.zero);
    expect(radiusOf(1), BorderRadius.zero);
    expect(radiusOf(2).bottomRight, const Radius.circular(24));
    // Un filet au-dessus de chaque ligne sauf la première.
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('a section label is read as a header', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(const ShelfSectionLabel('6 séries, de A à Z'));

    expect(
      tester.getSemantics(find.text('6 séries, de A à Z')),
      matchesSemantics(label: '6 séries, de A à Z', isHeader: true),
    );
    semantics.dispose();
  });
}
