import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:flutter/material.dart';

/// Avatar d'une personne : photo si disponible, sinon initiales sur une teinte
/// stable dérivée du nom (comme Google Contacts). Décoratif : le nom est lu à côté.
class AnKiAvatar extends StatelessWidget {
  const AnKiAvatar({
    super.key,
    required this.name,
    this.image,
    this.radius = 24,
  });

  final String name;
  final ImageProvider? image;
  final double radius;

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
    return ExcludeSemantics(
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
  }
}
