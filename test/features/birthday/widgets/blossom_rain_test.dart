import 'package:an_ki/features/birthday/widgets/blossom_rain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const colors = [Color(0xE6FFD9DC), Color(0x99FFFFFF), Color(0xBFE1E0FF)];
  late int plays;

  setUp(() => plays = 0);

  /// La pluie sur une carte de 300 × 150, animations coupées ou non.
  Future<void> pumpRain(
    WidgetTester tester, {
    bool play = true,
    bool reduceMotion = false,
  }) => tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Center(
        child: SizedBox(
          width: 300,
          height: 150,
          child: BlossomRain(colors: colors, play: play, onPlay: () => plays++),
        ),
      ),
    ),
  );

  RenderObject rain(WidgetTester tester) => tester.renderObject(
    find.descendant(
      of: find.byType(BlossomRain),
      matching: find.byType(CustomPaint),
    ),
  );

  testWidgets('lets the petals fall once, then paints nothing', (tester) async {
    await pumpRain(tester);
    await tester.pump();

    expect(plays, 1);
    await tester.pump(const Duration(milliseconds: 900));
    expect(rain(tester), paints..path());

    await tester.pump(BlossomRain.duration);
    expect(rain(tester), paintsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('falls within the 2.5 s of the identity', () {
    expect(
      BlossomRain.duration,
      lessThanOrEqualTo(const Duration(milliseconds: 2500)),
    );
  });

  testWidgets('stays still when animations are turned off', (tester) async {
    await pumpRain(tester, reduceMotion: true);
    await tester.pump(const Duration(milliseconds: 900));

    expect(plays, 0);
    expect(rain(tester), paintsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('stays still when told not to play', (tester) async {
    await pumpRain(tester, play: false);
    await tester.pump(const Duration(milliseconds: 900));

    expect(plays, 0);
    expect(rain(tester), paintsNothing);
  });

  testWidgets('finishes a rain already falling', (tester) async {
    await pumpRain(tester);
    await tester.pump(const Duration(milliseconds: 300));

    // L'appelant note la pluie comme tombée : elle continue quand même.
    await pumpRain(tester, play: false);
    await tester.pump(const Duration(milliseconds: 600));

    expect(rain(tester), paints..path());
    expect(plays, 1);
  });
}
