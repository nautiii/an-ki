import 'package:an_ki/features/books/widgets/glass_circle.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  testWidgets('puts its button on frosted glass, still tappable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpHarness(
      GlassCircle(
        child: IconButton(
          onPressed: () => taps++,
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(GlassCircle),
        matching: find.byType(DecoratedBox),
      ),
    );
    final context = tester.element(find.byType(GlassCircle));
    expect((box.decoration as ShapeDecoration).color, context.ankiColors.glass);

    await tester.tap(find.byTooltip('Retour'));
    expect(taps, 1);
  });
}
