import 'dart:math' as math;

import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final light = AppTheme.light.colorScheme;
  final dark = AppTheme.dark.colorScheme;

  test('hero is lotus to cloud by day, berry to night blue by night', () {
    final day = AnKiColors.from(light);
    final nightColors = AnKiColors.from(dark);

    expect(day.hero.colors, [light.primaryFixedDim, light.tertiaryFixedDim]);
    expect(day.onHero, light.onPrimaryFixed);
    expect(nightColors.hero.colors, const [
      Color(0xFF7A1035),
      Color(0xFF1E3F6E),
    ]);
    expect(nightColors.onHero, const Color(0xFFFFE0E5));
  });

  test('celebration is raspberry by day, plum by night', () {
    final day = AnKiColors.from(light);
    final nightColors = AnKiColors.from(dark);

    // Le bout clair est le `primary` vibrant du rouge prune de l'icône.
    expect(day.celebration.colors, const [
      Color(0xFFA8003D),
      Color(0xFFC0001D),
    ]);
    expect(day.onCelebration, Colors.white);
    expect(day.onCelebrationAction, const Color(0xFFA8003D));
    expect(nightColors.celebration.colors, const [
      Color(0xFF7A0030),
      Color(0xFF9B1B30),
    ]);
    expect(nightColors.onCelebration, const Color(0xFFFFE0E5));
    expect(nightColors.onCelebrationAction, const Color(0xFF7A0030));
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
        // Texte secondaire du jour J : 85 % d'opacité minimum.
        final secondary = Color.alphaBlend(
          colors.onCelebration.withValues(alpha: 0.85),
          background,
        );
        expect(_contrast(secondary, background), greaterThanOrEqualTo(4.5));
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

  test('owned spines stand out from the surface, their number readable', () {
    for (final scheme in [light, dark]) {
      final colors = AnKiColors.from(scheme);
      // Le dos (clair) ou son bord (sombre) dessine le livre : 3:1 au moins.
      expect(
        math.max(
          _contrast(colors.spine, scheme.surface),
          _contrast(colors.spineEdge, scheme.surface),
        ),
        greaterThanOrEqualTo(3),
      );
      for (final fill in [colors.spine, colors.spineAlt]) {
        expect(_contrast(colors.onSpine, fill), greaterThanOrEqualTo(4.5));
      }
    }
    final day = AnKiColors.from(light);
    final nightColors = AnKiColors.from(dark);
    expect(day.spine, light.secondary);
    expect(nightColors.spine, dark.secondaryContainer);
    expect(day.lerp(nightColors, 1).spineEdge, nightColors.spineEdge);
    expect(day.lerp(nightColors, 1).spineAlt, nightColors.spineAlt);
    expect(day.copyWith(spineAlt: const Color(0xFF000000)).spineAlt.a, 1);
    const red = Color(0xFFFF0000);
    expect(day.copyWith(spine: red, onSpine: red, spineEdge: red).spine, red);
  });

  test('petals take three tones per theme, softer at night', () {
    final day = AnKiColors.from(light);
    final nightColors = AnKiColors.from(dark);

    expect(day.petals, hasLength(3));
    expect(nightColors.petals, hasLength(3));
    // Lotus clair, lotus profond, or des étamines.
    expect(day.petals.last.withValues(alpha: 1), const Color(0xFFFFD849));
    for (final (index, petal) in nightColors.petals.indexed) {
      expect(petal.a, lessThan(day.petals[index].a));
    }
    expect(day.lerp(nightColors, 1).petals, nightColors.petals);
    expect(day.copyWith(petals: const []).petals, isEmpty);
  });

  test('floating elements cast a lotus shadow in light only', () {
    final shadow = AnKiColors.from(light).floatingShadow.single;

    expect(shadow.color.withValues(alpha: 1), light.primary);
    expect(shadow.color.a, lessThanOrEqualTo(0.14));
    expect(AnKiColors.from(dark).floatingShadow, isEmpty);
  });

  test('the moon stays lavender, the mascot of the identity', () {
    expect(
      AnKiColors.from(light).moonlight.color,
      TonalColors.fromSeed(AnKiColors.moonSeed, Brightness.light).color,
    );
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
    const lotus = AnKiColors.lotusSeed;
    expect(
      TonalColors.of(lotus, Brightness.light),
      same(TonalColors.of(lotus, Brightness.light)),
    );
    expect(
      TonalColors.of(lotus, Brightness.dark),
      isNot(same(TonalColors.of(lotus, Brightness.light))),
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
