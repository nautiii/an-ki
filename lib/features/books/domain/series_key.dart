import 'package:an_ki/core/text/text_folding.dart';

/// Clé de rapprochement d'un nom de série : un scan rejoint la série dont une
/// clé égale la sienne (voir `Series.keys`).
///
/// Le nom est replié par [foldForMatching] (casse, accents, tirets), puis la
/// ponctuation devient une espace : « L'Attaque des Titans » et « l attaque des
/// titans » se rapprochent, « One Piece » et « One-Piece » aussi. Les mots
/// restent : « Dragon Ball Perfect Edition » est une autre série que
/// « Dragon Ball ».
String seriesKey(String name) =>
    foldForMatching(name.replaceAll(_punctuation, ' ').replaceAll(_marks, ''));

/// Tout sauf lettres, chiffres et accents combinants (l'espace est replié
/// ensuite).
final _punctuation = RegExp(r'[^\p{L}\p{N}\p{M}\s]', unicode: true);

/// Accents combinants d'un texte décomposé (NFD) : « e » + U+0301 vaut « é ».
final _marks = RegExp(r'\p{M}', unicode: true);
