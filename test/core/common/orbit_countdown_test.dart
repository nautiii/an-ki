import 'package:an_ki/core/common/orbit_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  test('the orbit closes on the day and is untouched from 29 days out', () {
    expect(OrbitCountdown.progressFor(0), 1);
    expect(OrbitCountdown.progressFor(-2), 1);
    expect(OrbitCountdown.progressFor(29), 0);
    expect(OrbitCountdown.progressFor(120), 0);
    expect(
      OrbitCountdown.progressFor(7),
      greaterThan(OrbitCountdown.progressFor(14)),
    );
  });

  Future<Size> pumpOrbit(
    WidgetTester tester, {
    double textScale = 1,
    double? maxTextScale,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpHarness(
      Center(
        child: OrbitCountdown(
          daysLeft: 12,
          maxTextScale: maxTextScale,
          child: const Text('12'),
        ),
      ),
    );
    return tester.getSize(find.byType(OrbitCountdown));
  }

  testWidgets('shows its number inside the orbit', (tester) async {
    final size = await pumpOrbit(tester);

    expect(find.text('12'), findsOneWidget);
    expect(size, const Size.square(OrbitCountdown.defaultDiameter));
  });

  testWidgets('grows with the text size', (tester) async {
    final size = await pumpOrbit(tester, textScale: 2);

    expect(size.width, 2 * OrbitCountdown.defaultDiameter);
  });

  testWidgets('stops growing at its cap, its number shrinking to fit', (
    tester,
  ) async {
    final size = await pumpOrbit(tester, textScale: 2, maxTextScale: 1.2);

    expect(size.width, closeTo(1.2 * OrbitCountdown.defaultDiameter, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps its content inside the circle, wide as it may be', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpHarness(
      const Center(
        child: OrbitCountdown(
          daysLeft: 120,
          maxTextScale: 1.2,
          child: Text('365 jours'),
        ),
      ),
    );

    final orbit = tester.getRect(find.byType(OrbitCountdown));
    // Rectangle à l'écran, réduction du FittedBox comprise.
    final text = tester.getRect(find.text('365 jours'));
    // Le texte réduit tient dans le carré inscrit au cercle, centré.
    final inner = OrbitCountdown.innerSideOf(orbit.width);
    expect(text.width, lessThanOrEqualTo(inner + 0.01));
    expect(text.width, lessThan(tester.getSize(find.byType(Text)).width));
    expect(text.center.dx, closeTo(orbit.center.dx, 0.01));
    expectCornersFree(orbit, text);
  });

  testWidgets('keeps a number and its unit clear of the moon', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // Nombre et unité : un contenu presque carré, où les coins comptent.
    await tester.pumpHarness(
      const Center(
        child: OrbitCountdown(
          daysLeft: 11,
          maxTextScale: 1.2,
          child: Column(
            key: Key('content'),
            mainAxisSize: MainAxisSize.min,
            children: [Text('120'), Text('jours')],
          ),
        ),
      ),
    );

    expectCornersFree(
      tester.getRect(find.byType(OrbitCountdown)),
      tester.getRect(find.byKey(const Key('content'))),
    );
  });
}

/// Mesuré sans la formule : chaque coin de [content], à sa place à l'écran,
/// reste dans le cercle que la lune laisse libre sur [orbit], où qu'elle soit.
void expectCornersFree(Rect orbit, Rect content) {
  final free = orbit.width / 2 - 2 * OrbitCountdown.moonRadius;
  for (final corner in [
    content.topLeft,
    content.topRight,
    content.bottomLeft,
    content.bottomRight,
  ]) {
    expect((corner - orbit.center).distance, lessThanOrEqualTo(free + 0.01));
  }
}
