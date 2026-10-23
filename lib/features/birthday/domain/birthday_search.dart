import 'package:an_ki/features/birthday/domain/birthday.dart';

/// Plage trouvée dans un texte : de [start] inclus à [end] exclu, en indices
/// de `String` (unités UTF-16).
typedef MatchRange = ({int start, int end});

/// Règle de recherche sur une liste d'anniversaires.
extension BirthdaySearch on Iterable<Birthday> {
  /// Anniversaires dont le prénom, le nom ou le nom complet contient [query]
  /// (sans tenir compte de la casse ni des accents : « lea » trouve « Léa »)
  /// et qui portent toutes les catégories de [categoryIds]. Un texte vide
  /// garde tout le monde.
  List<Birthday> matching(String query, {List<String> categoryIds = const []}) {
    final needle = _fold(query.trim()).text;
    return [
      for (final birthday in this)
        if (categoryIds.every(birthday.categories.contains) &&
            _fold(birthday.fullName).text.contains(needle))
          birthday,
    ];
  }
}

/// Lettres du nom qu'une recherche a trouvées.
extension BirthdayNameMatch on Birthday {
  /// Plage de [Birthday.fullName] trouvée par [query], comparée comme dans
  /// [BirthdaySearch.matching] ; null pour un texte vide ou sans
  /// correspondance. Entre plusieurs, un début de mot l'emporte (« ma » dans
  /// « Emma Martin » : Martin), sinon la première.
  MatchRange? nameMatch(String query) {
    final needle = _fold(query.trim()).text;
    if (needle.isEmpty) return null;
    final name = _fold(fullName);

    int? found;
    for (
      var index = name.text.indexOf(needle);
      index >= 0;
      index = name.text.indexOf(needle, index + 1)
    ) {
      found ??= index;
      if (index == 0 || !_wordCharacter.hasMatch(name.text[index - 1])) {
        found = index;
        break;
      }
    }
    if (found == null) return null;
    return (
      start: name.starts[found],
      end: name.ends[found + needle.length - 1],
    );
  }
}

/// Lettre ou chiffre : ce qui continue un mot.
final _wordCharacter = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Texte ramené à sa forme de comparaison (minuscules, sans accents), avec
/// pour chacune de ses unités la plage du texte d'origine dont elle vient :
/// une plage trouvée dans [text] se relit ainsi dans l'original.
({String text, List<int> starts, List<int> ends}) _fold(String source) {
  final text = StringBuffer();
  final starts = <int>[];
  final ends = <int>[];
  var index = 0;
  for (final rune in source.runes) {
    final length = rune > 0xFFFF ? 2 : 1;
    for (final unit in String.fromCharCode(rune).toLowerCase().codeUnits) {
      // Accent combinant (« e » suivi de « ◌́ ») : retiré de la forme de
      // comparaison, mais rattaché à la lettre qui le porte.
      if (unit >= 0x0300 && unit <= 0x036F) {
        if (ends.isNotEmpty) ends.last = index + length;
        continue;
      }
      final folded = _baseLetters[unit] ?? String.fromCharCode(unit);
      for (var i = 0; i < folded.length; i++) {
        starts.add(index);
        ends.add(index + length);
      }
      text.write(folded);
    }
    index += length;
  }
  return (text: text.toString(), starts: starts, ends: ends);
}

/// Lettre de base de chaque lettre accentuée (minuscules latines), et les
/// ligatures épelées : « œ » se cherche « oe ».
final Map<int, String> _baseLetters = {
  for (final MapEntry(key: base, value: variants) in const {
    'a': 'àáâãäåāăą',
    'ae': 'æ',
    'c': 'çćĉċč',
    'd': 'ďđ',
    'e': 'èéêëēĕėęě',
    'g': 'ĝğġģ',
    'h': 'ĥħ',
    'i': 'ìíîïĩīĭįı',
    'j': 'ĵ',
    'k': 'ķ',
    'l': 'ĺļľŀł',
    'n': 'ñńņňŉ',
    'o': 'òóôõöøōŏő',
    'oe': 'œ',
    'r': 'ŕŗř',
    's': 'śŝşšș',
    'ss': 'ß',
    't': 'ţťŧț',
    'u': 'ùúûüũūŭůűų',
    'w': 'ŵ',
    'y': 'ýÿŷ',
    'z': 'źżž',
    // Apostrophe typographique des contacts importés : « D’Amico ».
    "'": '’ʼ',
  }.entries)
    for (final unit in variants.codeUnits) unit: base,
};
