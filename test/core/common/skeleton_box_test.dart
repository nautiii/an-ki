import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  testWidgets('pulses while animations are enabled', (tester) async {
    await tester.pumpHarness(const SkeletonBox(height: 72));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('stays still when animations are disabled', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpHarness(const SkeletonBox(height: 72));
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('is hidden from screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(const SkeletonBox(height: 72));

    expect(
      find.descendant(
        of: find.byType(SkeletonBox),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
