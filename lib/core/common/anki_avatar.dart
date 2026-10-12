import 'dart:math' as math;

import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:flutter/material.dart';

/// Avatar d'une personne : photo si disponible, sinon initiales sur une teinte
/// stable dérivée du nom (comme Google Contacts). Décoratif : le nom est lu à côté.
///
/// Avec [ringColors], un anneau fin l'entoure : une part égale par couleur,
/// fondue dans la suivante (les catégories d'une personne, par exemple).
class AnKiAvatar extends StatelessWidget {
  const AnKiAvatar({
    super.key,
    required this.name,
    this.image,
    this.radius = 24,
    this.ringColors,
  });

  final String name;
  final ImageProvider? image;
  final double radius;

  /// Couleurs de l'anneau. `null` : ni anneau ni place réservée ; liste
  /// vide : la place seule, pour garder les avatars d'une liste alignés.
  final List<Color>? ringColors;

  /// Épaisseur de l'anneau.
  static const double ringWidth = 2;

  /// Espace entre l'anneau et l'avatar.
  static const double ringGap = 2;

  // Graines tirées des illustrations : nuit, lotus, feuille, lune, nuage.
  static const List<Color> _seeds = [
    Color(0xFF073165),
    Color(0xFFF88898),
    Color(0xFF70D8B8),
    Color(0xFFD0D0F8),
    Color(0xFFC0D8F8),
  ];

  /// Deux initiales au plus, en majuscules (« Léa Martin » → « LM »).
  static String initialsOf(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part.characters.first.toUpperCase())
      .join();

  /// Couleurs et arrêts du dégradé circulaire de l'anneau : chaque couleur
  /// tient une part égale du tour, avec un court fondu à chaque jonction.
  static ({List<Color> colors, List<double> stops}) ringSegments(
    List<Color> colors,
  ) {
    final count = colors.length;
    // Fondu de part et d'autre d'une jonction, borné pour les petites parts.
    final blend = math.min(0.04, 1 / (4 * count));
    final seam = Color.lerp(colors.last, colors.first, 0.5)!;
    return (
      colors: [
        seam,
        for (final color in colors) ...[color, color],
        seam,
      ],
      stops: [
        0,
        for (var i = 0; i < count; i++) ...[
          i / count + blend,
          (i + 1) / count - blend,
        ],
        1,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hash déterministe : String.hashCode n'est pas garanti stable entre versions.
    final hash = name.codeUnits.fold<int>(
      0,
      (h, c) => (h * 31 + c) & 0x7fffffff,
    );
    final tones = TonalColors.of(
      _seeds[hash % _seeds.length],
      Theme.of(context).brightness,
    );
    final initials = initialsOf(name);
    final avatar = ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: tones.container,
        foregroundImage: image,
        child: initials.isEmpty
            ? Icon(Icons.person_rounded, color: tones.onContainer)
            : Text(
                initials,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tones.onContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );

    final ring = ringColors;
    if (ring == null) return avatar;
    return CustomPaint(
      painter: _RingPainter(ring),
      child: Padding(
        padding: const EdgeInsets.all(ringGap + ringWidth),
        child: avatar,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - AnKiAvatar.ringWidth) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AnKiAvatar.ringWidth
      ..isAntiAlias = true;
    if (colors.length == 1) {
      paint.color = colors.single;
    } else {
      final segments = AnKiAvatar.ringSegments(colors);
      // Départ en haut, sens horaire.
      paint.shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: segments.colors,
        stops: segments.stops,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    }
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      !_sameColors(oldDelegate.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
