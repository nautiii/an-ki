import 'dart:math' as math;

import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const night = Color(0xFF073165);
  final light = ColorScheme.fromSeed(seedColor: night);
  final dark = ColorScheme.fromSeed(
    seedColor: night,
    brightness: Brightness.dark,
  );

  test('hero is a dusk gradient in light and a night sky in dark', () {
    final day = AnKiColors.from(light);
    final nightColors = AnKiColors.from(dark);

    expect(day.hero.colors, [light.primary, light.tertiary]);
    expect(day.onHero, light.onPrimary);
    expect(nightColors.hero.colors, [
      dark.primaryContainer,
      dark.tertiaryContainer,
    ]);
    expect(nightColors.onHero, dark.onPrimaryContainer);
  });

  test('every brand pair meets WCAG AA in both themes', () {
    for (final scheme in [light, dark]) {
      final colors = AnKiColors.from(scheme);
      for (final background in colors.hero.colors) {
        expect(_contrast(colors.onHero, background), greaterThanOrEqualTo(4.5));
        // Texte secondaire du héros : 85 % d'opacité minimum.
        final secondary = Color.alphaBlend(
          colors.onHero.withValues(alpha: 0.85),
          background,
        );
        expect(_contrast(secondary, background), greaterThanOrEqualTo(4.5));
      }
      for (final background in colors.celebration.colors) {
        expect(
          _contrast(colors.onCelebration, background),
          greaterThanOrEqualTo(4.5),
        );
      }
      // « Souhaiter » : bouton plein [onCelebration], texte dessus.
      expect(
        _contrast(colors.onCelebrationAction, colors.onCelebration),
        greaterThanOrEqualTo(4.5),
      );
      for (final tones in [colors.blossom, colors.success, colors.moonlight]) {
        expect(
          _contrast(tones.onColor, tones.color),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(tones.onContainer, tones.container),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });

  test('floating elements cast a shadow in light only', () {
    expect(AnKiColors.from(light).floatingShadow, isNotEmpty);
    expect(AnKiColors.from(dark).floatingShadow, isEmpty);
  });

  test('copyWith and lerp', () {
    final day = AnKiColors.from(light);
    final nightColors = AnKiColors.from(dark);
    const red = Color(0xFFFF0000);

    expect(day.copyWith(onHero: red).onHero, red);
    expect(day.copyWith().hero, day.hero);
    expect(day.lerp(null, 0.5), same(day));
    expect(day.lerp(nightColors, 0).onHero, day.onHero);
    expect(day.lerp(nightColors, 1).onHero, nightColors.onHero);
    expect(
      day.lerp(nightColors, 1).success.container,
      nightColors.success.container,
    );
    expect(
      day.lerp(nightColors, 1).onCelebrationAction,
      nightColors.onCelebrationAction,
    );
    expect(day.copyWith(onCelebrationAction: red).onCelebrationAction, red);
  });

  test('TonalColors.of caches one instance per seed and brightness', () {
    expect(
      TonalColors.of(night, Brightness.light),
      same(TonalColors.of(night, Brightness.light)),
    );
    expect(
      TonalColors.of(night, Brightness.dark),
      isNot(same(TonalColors.of(night, Brightness.light))),
    );
  });

  testWidgets('context.ankiColors falls back when the extension is missing', (
    tester,
  ) async {
    late AnKiColors colors;
    await tester.pumpHarness(
      Builder(
        builder: (context) {
          colors = context.ankiColors;
          return const SizedBox();
        },
      ),
    );

    expect(colors.hero.colors, hasLength(2));
  });
}
