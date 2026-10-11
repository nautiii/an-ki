import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  test('layout spacing stays on the 4dp baseline grid', () {
    for (final value in [
      AppSpacing.xxs,
      AppSpacing.xs,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.xxl,
    ]) {
      expect(value % 4, 0);
    }
    expect(AppSpacing.gutter % 8, 0);
  });

  Future<Duration> motionFor(WidgetTester tester) async {
    late Duration duration;
    await tester.pumpHarness(
      Builder(
        builder: (context) {
          duration = context.motion(AppMotion.enter);
          return const SizedBox();
        },
      ),
    );
    return duration;
  }

  testWidgets('motion keeps durations when animations are enabled', (
    tester,
  ) async {
    expect(await motionFor(tester), AppMotion.enter);
  });

  testWidgets('motion collapses durations when animations are disabled', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    expect(await motionFor(tester), Duration.zero);
  });
}
