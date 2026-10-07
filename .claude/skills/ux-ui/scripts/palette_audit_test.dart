// ignore_for_file: avoid_print
//
// PALETTE AUDIT — outil du skill `ux-ui` (source : .claude/skills/ux-ui/scripts/).
// Imprime les rôles réels du ColorScheme (clair + sombre) et vérifie le contraste
// des couples premier plan / fond utilisés par l'UI (WCAG 2.2 AA) :
// texte 4.5:1 · gros texte (≥ 24px, ou ≥ 18.66px gras) 3:1 · bordures/icônes utiles 3:1.
//
// 1. mkdir -p build/ui_snapshots/_src && cp .claude/skills/ux-ui/scripts/*.dart build/ui_snapshots/_src/
// 2. Ajouter dans PAIRS les couples du composant travaillé (alpha et ThemeExtension compris).
// 3. flutter test build/ui_snapshots/_src/palette_audit_test.dart

import 'dart:math' as math;

import 'package:an_ki/core/theme/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══ COUPLES À VÉRIFIER — compléter selon le composant ════════════════════════

final List<Pair> pairs = [
  Pair(
    'texte principal',
    (t) => t.colorScheme.onSurface,
    (t) => t.colorScheme.surface,
  ),
  Pair(
    'texte secondaire',
    (t) => t.colorScheme.onSurfaceVariant,
    (t) => t.colorScheme.surface,
  ),
  Pair(
    'texte secondaire sur carte',
    (t) => t.colorScheme.onSurfaceVariant,
    (t) => t.colorScheme.surfaceContainerHigh,
  ),
  Pair(
    'accent / lien',
    (t) => t.colorScheme.primary,
    (t) => t.colorScheme.surface,
  ),
  Pair(
    'bouton plein',
    (t) => t.colorScheme.onPrimary,
    (t) => t.colorScheme.primary,
  ),
  Pair(
    'tonal primaire (chips, badges)',
    (t) => t.colorScheme.onPrimaryContainer,
    (t) => t.colorScheme.primaryContainer,
  ),
  Pair(
    'tonal tertiaire',
    (t) => t.colorScheme.onTertiaryContainer,
    (t) => t.colorScheme.tertiaryContainer,
  ),
  Pair('erreur', (t) => t.colorScheme.error, (t) => t.colorScheme.surface),
  Pair(
    'bordure de champ (composant)',
    (t) => t.colorScheme.outline,
    (t) => t.colorScheme.surface,
    min: 3.0,
  ),
  Pair(
    'outlineVariant = décoratif seulement',
    (t) => t.colorScheme.outlineVariant,
    (t) => t.colorScheme.surface,
    min: 1.0,
  ),
  // Carte héros actuelle : dégradé primary → tertiary, texte onPrimary à 70 %.
  Pair(
    'héros : texte 70 % (début dégradé)',
    (t) => t.colorScheme.onPrimary,
    (t) => t.colorScheme.primary,
    alpha: 0.7,
  ),
  Pair(
    'héros : texte 70 % (fin dégradé)',
    (t) => t.colorScheme.onPrimary,
    (t) => t.colorScheme.tertiary,
    alpha: 0.7,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('palette audit', () async {
    await _warmUpTheme();
    for (final (name, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      final s = theme.colorScheme;
      print('\n── palette $name');
      print(
        '   primary ${_hex(s.primary)} · onPrimary ${_hex(s.onPrimary)} · '
        'primaryContainer ${_hex(s.primaryContainer)} · tertiary ${_hex(s.tertiary)} · '
        'tertiaryContainer ${_hex(s.tertiaryContainer)}',
      );
      print(
        '   surface ${_hex(s.surface)} · containerLow ${_hex(s.surfaceContainerLow)} · '
        'container ${_hex(s.surfaceContainer)} · containerHigh ${_hex(s.surfaceContainerHigh)} · '
        'onSurface ${_hex(s.onSurface)} · onSurfaceVariant ${_hex(s.onSurfaceVariant)}',
      );
      for (final pair in pairs) {
        final bg = pair.bg(theme);
        final fg = Color.alphaBlend(
          pair.fg(theme).withValues(alpha: pair.alpha),
          bg,
        );
        final ratio = _contrast(fg, bg);
        final ok = ratio >= pair.min;
        final alpha = pair.alpha < 1 ? ' @${(pair.alpha * 100).round()}%' : '';
        print(
          '   ${ok ? '✓' : '✗'} ${ratio.toStringAsFixed(2).padLeft(5)} '
          '${pair.label}$alpha (min ${pair.min})',
        );
      }
    }
  });
}

/// Couple premier plan (alpha éventuel) / fond, lus depuis le ThemeData réel.
class Pair {
  const Pair(this.label, this.fg, this.bg, {this.min = 4.5, this.alpha = 1.0});

  final String label;
  final Color Function(ThemeData theme) fg;
  final Color Function(ThemeData theme) bg;
  final double min;
  final double alpha;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

// Construire AppTheme déclenche google_fonts (sans réseau en test) : on le fait
// taire, les couleurs n'en dépendent pas.
Future<void> _warmUpTheme() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {};
  try {
    await GoogleFonts.pendingFonts([AppTheme.light, AppTheme.dark]);
  } catch (_) {
    // Attendu tant que la police n'est pas embarquée.
  } finally {
    debugPrint = originalDebugPrint;
  }
}
