import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/volume_number.dart';

/// Série et numéro trouvés pour un livre.
class const VolumeGuess({
  /// Nom de la série, sans le numéro ni le titre du tome. Les éditions
  /// (« Perfect Edition », « Deluxe », « Colossale », « Intégrale ») en font
  /// partie : ce sont d'autres séries.
  required final String seriesName,

  /// Numéro du tome, entre 1 et [maxVolumeNumber].
  required final int number,
  required final GuessConfidence confidence,
}) {
  @override
  bool operator ==(Object other) =>
      other is VolumeGuess &&
      other.seriesName == seriesName &&
      other.number == number &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(seriesName, number, confidence);
}

/// Degré de certitude d'un [VolumeGuess] ; l'UI décide ce qu'elle range seule.
enum GuessConfidence {
  /// Numéro en chiffres romains, numéro placé devant le nom (« Tome 12 - One
  /// Piece »), ou repère suivi d'un mot (« Spirou n° 1 spécial », « Vol 714
  /// pour Sydney ») : peut-être du texte courant. À proposer, pas à imposer.
  low,

  /// Un repère explicite (« Tome 108 », « T15 », « Vol. 3 », « #12 », « n° 4 »)
  /// derrière un nom de série, et suivi de la fin du titre ou d'un séparateur
  /// (« Tome 7 : Alors, tout tombe »).
  medium,

  /// Champs structurés de la BnF (225/461) : série et numéro catalogués.
  high,
}

/// Trouve la série et le numéro du livre décrit par [record], ou null quand
/// rien n'est sûr.
///
/// 1. Les champs structurés de la BnF (`seriesTitle` et `seriesNumber`) :
///    [GuessConfidence.high].
/// 2. Sinon le titre, puis le sous-titre, derrière un repère : « Tome 108 »,
///    « T15 », « T.15 », « Vol. 3 », « Volume 3 », « #12 », « n° 4 », en
///    chiffres arabes ou, après « tome » ou « vol », romains. Le nom est ce qui
///    précède le repère (« Blacksad, tome 7 : … » → « Blacksad ») ; le repère
///    en tête (« Tome 12 - One Piece ») donne le nom qui suit. Avec une série
///    structurée mais sans numéro, le numéro se cherche dans le titre.
/// 3. « Édition originale » est retirée ; « Perfect Edition », « Deluxe »,
///    « Colossale », « Intégrale » restent dans le nom.
/// 4. Un coffret, un hors-série, plusieurs tomes (« Tomes 1 à 3 »), un décimal
///    (« Tome 10.5 »), un numéro hors de 1 à [maxVolumeNumber], un nombre sans
///    repère (« Fahrenheit 451 », « Final Fantasy VII ») : null, le livre reste
///    « à classer ».
VolumeGuess? guessVolume(BookMetadata record) {
  final title = _clean(record.title);
  final subtitle = record.subtitle == null ? null : _clean(record.subtitle!);
  if (_excluded.hasMatch(title) ||
      (subtitle != null && _excluded.hasMatch(subtitle))) {
    return null;
  }

  final structuredName = record.seriesTitle == null
      ? null
      : _seriesName(_clean(record.seriesTitle!));
  final structuredNumber = record.seriesNumber;
  if (structuredName != null &&
      structuredNumber != null &&
      structuredNumber >= 1 &&
      structuredNumber <= maxVolumeNumber) {
    return VolumeGuess(
      seriesName: structuredName,
      number: structuredNumber,
      confidence: GuessConfidence.high,
    );
  }

  final inTitle = _findMarked(title);
  if (inTitle != null) {
    if (structuredName != null) {
      return VolumeGuess(
        seriesName: structuredName,
        number: inTitle.number,
        confidence: inTitle.confidence,
      );
    }
    final before = _seriesName(inTitle.before);
    if (before != null) {
      return VolumeGuess(
        seriesName: before,
        number: inTitle.number,
        confidence: inTitle.confidence,
      );
    }
    // Un article seul avant le repère (« Le Vol 93 ») : pas un nom de série.
    if (_hasWord(inTitle.before)) return null;
    // Le repère est en tête : « Tome 12 - One Piece », le nom suit.
    final after = _seriesName(_firstSegment(inTitle.after));
    if (after == null) return null;
    return VolumeGuess(
      seriesName: after,
      number: inTitle.number,
      confidence: GuessConfidence.low,
    );
  }

  // Aucun repère dans le titre : le titre est la série, le sous-titre porte
  // le numéro (« Les Fées Valentines » + « Tome 2 », ou « Naruto » + « 12 »).
  final name = structuredName ?? _seriesName(title);
  if (name == null || subtitle == null) return null;
  if (_bareNumber.hasMatch(subtitle)) {
    final number = int.parse(subtitle);
    if (number < 1 || number > maxVolumeNumber) return null;
    return VolumeGuess(
      seriesName: name,
      number: number,
      confidence: GuessConfidence.medium,
    );
  }
  final inSubtitle = _findMarked(subtitle);
  if (inSubtitle == null || _hasWord(inSubtitle.before)) return null;
  return VolumeGuess(
    seriesName: name,
    number: inSubtitle.number,
    confidence: inSubtitle.confidence,
  );
}

/// Un repère de numéro trouvé dans un texte.
class _Marked {
  const _Marked({
    required this.number,
    required this.before,
    required this.after,
    required this.confidence,
  });

  final int number;

  /// Texte avant le repère, et après le numéro.
  final String before;
  final String after;

  /// [GuessConfidence.medium] pour un numéro arabe qui termine le texte ou
  /// précède un séparateur (« Tome 7 : … ») ; [GuessConfidence.low] pour un
  /// chiffre romain, ou quand un mot suit le numéro (« Spirou n° 1 spécial »,
  /// « Vol 714 pour Sydney ») : le repère peut appartenir à du texte courant.
  final GuessConfidence confidence;
}

/// Premier repère de numéro valide de [text], sinon null.
_Marked? _findMarked(String text) {
  for (final match in _marker.allMatches(text)) {
    final rawMarker = match.group(1)!;
    final marker = rawMarker.toLowerCase().replaceAll('.', '');
    final raw = match.group(2)!;
    final roman = !_digits.hasMatch(raw);
    if (roman) {
      if (!_romanMarkers.contains(marker)) continue;
      // Un « T » seul suivi de lettres est trop courant (« Accro à la TV ») :
      // pour lui, il faut le point.
      if (marker == 't' && !rawMarker.endsWith('.')) continue;
    }
    final number = roman ? parseRoman(raw) : int.tryParse(raw);
    if (number == null || number < 1 || number > maxVolumeNumber) continue;
    final after = text.substring(match.end);
    return _Marked(
      number: number,
      before: text.substring(0, match.start),
      after: after,
      confidence: !roman && _endsOrSeparated.hasMatch(after)
          ? GuessConfidence.medium
          : GuessConfidence.low,
    );
  }
  return null;
}

final _digits = RegExp(r'^\d+$');

/// Le numéro termine le texte ou est suivi d'un séparateur.
final _endsOrSeparated = RegExp(r'^\s*(?:$|[-–—:,;.)\]])');

/// Repères qui acceptent un numéro romain.
const _romanMarkers = {'tome', 'volume', 'vol', 't'};

/// Repère (« tome », « T. », « Vol. », « n° », « # »), puis un numéro arabe ou
/// romain isolé, qui n'est pas la partie entière d'un décimal. Le repère ne
/// suit ni une lettre, ni un chiffre, ni une apostrophe (« Ain't I a Woman »).
final _marker = RegExp(
  r"(?<![\p{L}\p{N}'’])"
  r'(tome|volume|vol\.?|t\.?|n[°º]|no\.|num[ée]ro|#)'
  r'\s*(?:[.:#]\s*)?'
  r'(\d{1,4}|[ivxlc]{1,11})'
  r'(?![\p{L}\p{N}])(?![.,]\d)',
  caseSensitive: false,
  unicode: true,
);

/// Ce qui n'est pas un tome rangeable : coffret, hors-série, « tomes » au
/// pluriel, et plusieurs tomes d'un coup : « Tome 1 à 3 », « Tome 1 et 2 »,
/// « Tome 1 & 2 », « T1-T3 », « Tome 1-3 ». Un tiret espacé suivi d'un nombre
/// puis d'un mot (« Tome 5 - 2 cœurs ») est un titre de tome, pas un intervalle.
final _excluded = RegExp(
  r'(?<![\p{L}])(?:coffret|hors[\s-]+s[ée]rie|tomes|volumes)(?![\p{L}])'
  r'|(?<![\p{L}\p{N}])(?:tome|volume|vol\.?|t\.?|n[°º]|#)\s*\d{1,4}(?:'
  r'\s*(?:&|\+|/)\s*(?:(?:tome|volume|vol\.?|t\.?)\s*)?\d{1,4}(?![\p{L}\p{N}])'
  r'|\s+(?:à|a|et)\s+(?:(?:tome|volume|vol\.?|t\.?)\s*)?\d{1,4}(?![\p{L}\p{N}])'
  r'|[-–—](?:tome|volume|vol\.?|t\.?)\s*\d{1,4}(?![\p{L}\p{N}])'
  r'|[-–—]\d{1,4}(?![\p{L}\p{N}])'
  r'|\s+[-–—]\s+\d{1,4}(?![\p{L}\p{N}])(?!\s+\p{L})'
  r')',
  caseSensitive: false,
  unicode: true,
);

final _bareNumber = RegExp(r'^\d{1,4}$');

/// Longueur au-delà de laquelle un titre n'est plus lu : aucun titre réel ne
/// l'atteint, et les expressions ci-dessous restent rapides.
const _maxTextLength = 500;

/// [text] sans « Édition originale », espaces réduits, borné à
/// [_maxTextLength] caractères.
String _clean(String text) {
  var cleaned = text.replaceAll(_spaces, ' ').trim();
  if (cleaned.length > _maxTextLength) {
    cleaned = cleaned.substring(0, _maxTextLength);
  }
  return cleaned
      .replaceAll(_editionInBrackets, '')
      .replaceAll(_editionAfterSeparator, '')
      .replaceAll(_editionBare, '')
      .replaceAll(_spaces, ' ')
      .trim();
}

final _spaces = RegExp(r'\s+');

// Les espaces sont déjà réduits : au plus une espace avant chaque motif.
final _editionInBrackets = RegExp(
  r' ?[(\[] ?[ée]dition originale ?[)\]]',
  caseSensitive: false,
  unicode: true,
);

final _editionAfterSeparator = RegExp(
  r' ?[-–—,:] ?[ée]dition originale(?![\p{L}])',
  caseSensitive: false,
  unicode: true,
);

final _editionBare = RegExp(
  r'(?<![\p{L}])[ée]dition originale(?![\p{L}])',
  caseSensitive: false,
  unicode: true,
);

/// Articles qui ne font pas, seuls, le nom d'une série.
const _articles = {
  'le',
  'la',
  'les',
  'l',
  'un',
  'une',
  'des',
  'the',
  'a',
  'an',
};

/// [text] sans séparateurs ni parenthèse ouverte aux bords ; null s'il ne
/// reste ni lettre ni chiffre, ou qu'un article.
String? _seriesName(String text) {
  final name = text
      .replaceAll(RegExp(r'^[\s\-–—,:;)\]/]+'), '')
      .replaceAll(RegExp(r'[\s\-–—,:;(\[/]+$'), '');
  if (!_hasWord(name)) return null;
  final folded = name.toLowerCase().replaceAll(RegExp(r"['’]"), '');
  return _articles.contains(folded) ? null : name;
}

/// Vrai si [text] contient une lettre ou un chiffre.
bool _hasWord(String text) => _word.hasMatch(text);

final _word = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Premier morceau de [text] avant un tiret ou deux-points entouré d'espaces.
String _firstSegment(String text) {
  final trimmed = text.replaceAll(RegExp(r'^[\s\-–—,:;)\]/]+'), '');
  return trimmed.split(RegExp(r'\s[-–—:]\s')).first;
}
