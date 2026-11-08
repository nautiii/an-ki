import 'dart:math' as math;

import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:flutter/material.dart';

/// Compte à rebours en orbite (signature S3) : une petite lune fait le tour
/// d'un cercle fin autour de [child] (un nombre et son unité). L'arc parcouru
/// couvre les 29 derniers jours ; l'orbite se referme le jour J.
///
/// Le dessin est décoratif : [child] et le texte voisin portent l'information,
/// leur sémantique est celle de l'appelant.
class OrbitCountdown extends StatelessWidget {
  const OrbitCountdown({
    super.key,
    required this.daysLeft,
    required this.child,
    this.diameter = defaultDiameter,
    this.maxTextScale,
    this.trackColor,
    this.arcColor,
  });

  final int daysLeft;
  final Widget child;

  /// Diamètre à taille de texte normale ; il suit la taille du texte.
  final double diameter;

  /// Croissance maximale avec le texte (×) ; sans borne si null. Au-delà,
  /// [child] se réduit pour tenir dans l'orbite ([innerSideOf]).
  final double? maxTextScale;

  /// Cercle de l'orbite ; par défaut `outlineVariant`.
  final Color? trackColor;

  /// Arc parcouru et lune ; par défaut `moonlight.color`.
  final Color? arcColor;

  /// Diamètre d'une ligne d'agenda : la hauteur de l'avatar cerclé.
  static const double defaultDiameter = 56;

  /// Épaisseur du trait.
  static const double strokeWidth = 2.5;

  /// Rayon de la lune posée sur l'orbite.
  static const double moonRadius = 3.5;

  /// Part parcourue : 0 à 29 jours ou plus, 1 le jour J.
  static double progressFor(int daysLeft) =>
      daysLeft >= 29 ? 0 : 1 - daysLeft.clamp(0, 29) / 29;

  /// Côté du carré inscrit dans le cercle que la lune laisse libre (son bord
  /// intérieur, où qu'elle soit sur l'orbite), pour une orbite de [side] : la
  /// place du contenu, qui garde ainsi de l'air jusqu'au trait.
  static double innerSideOf(double side) =>
      (side - 4 * moonRadius) / math.sqrt2;

  /// Diamètre effectif dans [context], à sa taille de texte.
  static double extentOf(
    BuildContext context, {
    double diameter = defaultDiameter,
    double? maxTextScale,
  }) {
    final scaled = MediaQuery.textScalerOf(context).scale(diameter);
    return maxTextScale == null
        ? scaled
        : math.min(scaled, diameter * maxTextScale);
  }

  @override
  Widget build(BuildContext context) {
    final side = extentOf(
      context,
      diameter: diameter,
      maxTextScale: maxTextScale,
    );
    return CustomPaint(
      painter: _OrbitPainter(
        progress: progressFor(daysLeft),
        track: trackColor ?? Theme.of(context).colorScheme.outlineVariant,
        arc: arcColor ?? context.ankiColors.moonlight.color,
      ),
      child: SizedBox.square(
        dimension: side,
        child: Center(
          // Le contenu tient dans le carré inscrit au bord intérieur de la
          // lune : il ne touche jamais l'orbite, même réduit.
          child: SizedBox.square(
            dimension: innerSideOf(side),
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({
    required this.progress,
    required this.track,
    required this.arc,
  });

  final double progress;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - OrbitCountdown.moonRadius;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = OrbitCountdown.strokeWidth
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, stroke..color = track);
    // Départ en haut, sens horaire.
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        stroke
          ..color = arc
          ..strokeCap = StrokeCap.round,
      );
    }
    final angle = -math.pi / 2 + 2 * math.pi * progress;
    canvas.drawCircle(
      center + Offset(math.cos(angle), math.sin(angle)) * radius,
      OrbitCountdown.moonRadius,
      Paint()..color = arc,
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.arc != arc;
}
