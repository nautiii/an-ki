import 'package:an_ki/core/common/moon_phase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  RenderObject moon(WidgetTester tester) => tester.renderObject(
    find.descendant(
      of: find.byType(MoonPhase),
      matching: find.byType(CustomPaint),
    ),
  );

  test('illumination is full on the day and empty from 29 days out', () {
    expect(MoonPhase.illuminationFor(0), 1);
    expect(MoonPhase.illuminationFor(-2), 1);
    expect(MoonPhase.illuminationFor(29), 0);
    expect(MoonPhase.illuminationFor(120), 0);
    expect(
      MoonPhase.illuminationFor(7),
      greaterThan(MoonPhase.illuminationFor(14)),
    );
  });

  testWidgets('a new moon paints only its shadow disc', (tester) async {
    await tester.pumpHarness(const MoonPhase(daysLeft: 40));

    expect(moon(tester), paints..circle());
    expect(
      moon(tester),
      isNot(
        paints
          ..circle()
          ..path(),
      ),
    );
  });

  testWidgets('the lit part appears as the day approaches', (tester) async {
    await tester.pumpHarness(const MoonPhase(daysLeft: 5));

    expect(
      moon(tester),
      paints
        ..circle()
        ..path(),
    );
  });

  testWidgets('stays out of the semantics tree', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(const MoonPhase(daysLeft: 3));

    expect(
      find.descendant(
        of: find.byType(MoonPhase),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
