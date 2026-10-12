import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  test('initials keep at most two words, uppercased', () {
    expect(AnKiAvatar.initialsOf('Léa Martin'), 'LM');
    expect(AnKiAvatar.initialsOf('  élodie   de la Tour '), 'ÉD');
    expect(AnKiAvatar.initialsOf('Mamie'), 'M');
    expect(AnKiAvatar.initialsOf('   '), '');
  });

  testWidgets('shows the initials when there is no photo', (tester) async {
    await tester.pumpHarness(const AnKiAvatar(name: 'Léa Martin'));

    expect(find.text('LM'), findsOneWidget);
  });

  testWidgets('falls back to an icon for an empty name', (tester) async {
    await tester.pumpHarness(const AnKiAvatar(name: ''));

    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
  });

  testWidgets('the same name always gets the same tone', (tester) async {
    await tester.pumpHarness(
      const Column(
        children: [
          AnKiAvatar(name: 'Léa Martin'),
          AnKiAvatar(name: 'Léa Martin'),
        ],
      ),
    );

    final avatars = tester
        .widgetList<CircleAvatar>(find.byType(CircleAvatar))
        .toList();
    expect(avatars.first.backgroundColor, avatars.last.backgroundColor);
  });

  group('ring', () {
    const red = Color(0xFFB3261E);
    const blue = Color(0xFF425E91);

    testWidgets('takes no room without ring colors', (tester) async {
      await tester.pumpHarness(
        const Center(child: AnKiAvatar(name: 'Léa Martin')),
      );

      expect(tester.getSize(find.byType(AnKiAvatar)), const Size(48, 48));
    });

    testWidgets('keeps the room of an empty ring without drawing it', (
      tester,
    ) async {
      await tester.pumpHarness(
        const Center(
          child: AnKiAvatar(name: 'Léa Martin', ringColors: []),
        ),
      );

      expect(tester.getSize(find.byType(AnKiAvatar)), const Size(56, 56));
      expect(
        find.descendant(
          of: find.byType(AnKiAvatar),
          matching: find.byType(CustomPaint),
        ),
        isNot(paints..circle(style: PaintingStyle.stroke)),
      );
    });

    testWidgets('draws a thin circle around the avatar', (tester) async {
      await tester.pumpHarness(
        const Center(
          child: AnKiAvatar(name: 'Léa Martin', ringColors: [red, blue]),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(AnKiAvatar),
          matching: find.byType(CustomPaint),
        ),
        paints..circle(
          radius: 27,
          style: PaintingStyle.stroke,
          strokeWidth: AnKiAvatar.ringWidth,
        ),
      );
    });

    testWidgets('a single color is a plain ring', (tester) async {
      await tester.pumpHarness(
        const Center(
          child: AnKiAvatar(name: 'Léa Martin', ringColors: [red]),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(AnKiAvatar),
          matching: find.byType(CustomPaint),
        ),
        paints..circle(color: red),
      );
    });

    test('gives each color an equal share with soft joints', () {
      final segments = AnKiAvatar.ringSegments([red, blue]);
      final seam = Color.lerp(blue, red, 0.5);

      expect(segments.colors, [seam, red, red, blue, blue, seam]);
      expect(segments.stops, [0, 0.04, 0.46, 0.54, 0.96, 1]);
    });

    test('narrows the joints when the shares get small', () {
      final segments = AnKiAvatar.ringSegments(List.filled(10, red));

      expect(segments.stops[1], closeTo(0.025, 1e-9));
      expect(segments.stops[2], closeTo(0.075, 1e-9));
    });
  });
}
