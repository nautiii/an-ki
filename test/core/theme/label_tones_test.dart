import 'dart:math' as math;

import 'package:an_ki/core/theme/label_tones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('every label tone reads well in both themes', () {
    for (var index = 0; index < LabelTones.seeds.length; index++) {
      for (final brightness in Brightness.values) {
        final tones = LabelTones.of(index, brightness);
        final surface = ColorScheme.fromSeed(
          seedColor: const Color(0xFF073165),
          brightness: brightness,
        ).surface;

        // Puce : texte sur conteneur ; pastille : couleur pleine sur la surface.
        expect(
          _contrast(tones.onContainer, tones.container),
          greaterThanOrEqualTo(4.5),
        );
        expect(_contrast(tones.color, surface), greaterThanOrEqualTo(3));
      }
    }
  });

  test('wraps around the palette and caches each tone', () {
    expect(
      LabelTones.of(LabelTones.seeds.length, Brightness.light),
      same(LabelTones.of(0, Brightness.light)),
    );
    expect(
      LabelTones.of(LabelTones.neutral, Brightness.dark),
      same(LabelTones.of(LabelTones.neutral, Brightness.dark)),
    );
  });
}
