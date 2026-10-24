import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:flutter/material.dart';

/// Teintes des étiquettes de l'utilisateur (catégories) : chaque graine donne
/// une paire tonale accessible, en clair comme en sombre (identité §3.4).
///
/// Les teintes reprennent celles des anciennes couleurs brutes, pour que
/// chacun retrouve sa catégorie ; seules leurs nuances s'adaptent au thème.
abstract final class LabelTones {
  const LabelTones._();

  static const List<Color> seeds = [
    Color(0xFF2196F3), // bleu
    Color(0xFF4CAF50), // vert
    Color(0xFFFF9800), // orange
    Color(0xFFF44336), // rouge
    Color(0xFF9C27B0), // violet
    Color(0xFF00BCD4), // cyan
    Color(0xFF3F51B5), // indigo
    Color(0xFFFFC107), // ambre
    Color(0xFF795548), // brun
    Color(0xFF009688), // sarcelle
    Color(0xFFE91E63), // rose
    Color(0xFF673AB7), // violet profond
    Color(0xFFFFEB3B), // jaune
    Color(0xFFFF5722), // orange profond
    Color(0xFF9E9E9E), // gris
  ];

  /// Teinte des étiquettes sans couleur attitrée.
  static const int neutral = 14;

  /// Teintes proposées pour un nouveau groupe : des couleurs bien distinctes,
  /// sans le rouge (lu comme une erreur), le jaune, le brun ni le gris.
  static const List<int> pickable = [0, 1, 2, 4, 5, 10, 7, 9];

  /// Paire tonale de la graine [index] (modulo) pour [brightness].
  static TonalColors of(int index, Brightness brightness) =>
      TonalColors.of(seeds[index % seeds.length], brightness);
}
