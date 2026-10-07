import 'dart:math' as math;

import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:flutter/material.dart';

/// Compte à rebours en phases de lune (signature S3) : la lune croît sur les
/// 29 derniers jours et devient pleine le jour J.
///
/// Décoratif : toujours accompagné du texte « dans N jours », exclu de la sémantique.
class MoonPhase extends StatelessWidget {
  const MoonPhase({
    super.key,
    required this.daysLeft,
    this.size = 24,
    this.litColor,
    this.shadowColor,
  });

  final int daysLeft;
  final double size;

  /// Partie éclairée ; par défaut `moonlight.color` (encre en clair, lueur en sombre).
  final Color? litColor;

  /// Partie dans l'ombre ; par défaut la même teinte à 20 %.
  final Color? shadowColor;

  /// Fraction éclairée : 0 = nouvelle lune (≥ 29 jours), 1 = pleine lune (jour J).
  static double illuminationFor(int daysLeft) =>
      daysLeft >= 29 ? 0 : 1 - daysLeft.clamp(0, 29) / 29;

  @override
  Widget build(BuildContext context) {
    final moonlight = context.ankiColors.moonlight;
    final lit = litColor ?? moonlight.color;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _MoonPhasePainter(
          illumination: illuminationFor(daysLeft),
          lit: lit,
          shadow: shadowColor ?? lit.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

class _MoonPhasePainter extends CustomPainter {
  const _MoonPhasePainter({
    required this.illumination,
    required this.lit,
    required this.shadow,
  });

  final double illumination;
  final Color lit;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final disc = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius, Paint()..color = shadow);
    if (illumination <= 0) return;

    // Moitié droite éclairée (lune croissante), corrigée par l'ellipse du
    // terminateur : retranchée avant le premier quartier, ajoutée après.
    final rightHalf = Path()..addArc(disc, -math.pi / 2, math.pi);
    final terminator = Path()
      ..addOval(
        Rect.fromCenter(
          center: center,
          width: 2 * radius * (1 - 2 * illumination).abs(),
          height: 2 * radius,
        ),
      );
    final litPath = Path.combine(
      illumination > 0.5 ? PathOperation.union : PathOperation.difference,
      rightHalf,
      terminator,
    );
    canvas.drawPath(litPath, Paint()..color = lit);
  }

  @override
  bool shouldRepaint(_MoonPhasePainter oldDelegate) =>
      oldDelegate.illumination != illumination ||
      oldDelegate.lit != lit ||
      oldDelegate.shadow != shadow;
}
