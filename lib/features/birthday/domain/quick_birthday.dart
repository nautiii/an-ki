import 'package:an_ki/core/text/text_folding.dart';
import 'package:an_ki/features/birthday/domain/birth_date_input.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/domain/contact_import_preview.dart';
import 'package:flutter/foundation.dart';

/// Une personne tapée sur une ligne, « Léa 12 mars » : le nom tel qu'il est
/// écrit et la lecture de sa date ([BirthDateInput]).
class const QuickBirthday({
  /// Prénom puis nom, espaces réduits ; vide si la ligne n'en a pas.
  required final String fullName,
  required final BirthDateInput date,

  /// La ligne telle qu'elle a été tapée, pour nommer une ligne écartée qui
  /// n'a pas de nom (« 31/13 »). Hors de `==` : deux lignes qui disent la
  /// même chose sont la même lecture.
  final String source = '',
}) {
  /// Nom et date complète : la ligne peut devenir un anniversaire.
  bool get isReady =>
      BirthdayDraft.isValidName(fullName) && date is BirthDateComplete;

  /// La personne à enregistrer, ou null tant que la ligne n'est pas prête.
  BirthdayDraft? draft({
    List<String> categories = const [],
    Uint8List? picture,
  }) {
    if (date case BirthDateComplete(:final date) when isReady) {
      final (:name, :surname) = BirthdayDraft.splitFullName(fullName);
      return BirthdayDraft(
        name: name,
        surname: surname,
        date: date,
        categories: categories,
        picture: picture,
      );
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is QuickBirthday &&
      other.fullName == fullName &&
      other.date == date;

  @override
  int get hashCode => Object.hash(fullName, date);
}

/// Lit une ligne « nom + date » : « Léa 12 mars », « Mamie 3/2/50 »,
/// « Hugo Bernard 17 novembre 1990 », « 12/03 Zoé », « March 12, 1990 Tom ».
///
/// La date est en fin de ligne, sinon en début ; le nom est le reste. Elle
/// s'écrit en chiffres, jour et mois dans l'[order] de la région
/// ([parseBirthDate]), ou avec le mois en toutes lettres, français ou
/// anglais, entier ou abrégé, avant ou après le jour (« 1er mars »,
/// « mar 1 »). Un mot de mois ne compte qu'à côté d'un jour : « Avril » seul
/// est un prénom. L'année est facultative ; sur deux chiffres, c'est la plus
/// récente qui n'est pas après [today] (« 50 » → 1950, « 12 » → 2012). Un
/// « le », « né le » ou « on » devant la date est ignoré.
QuickBirthday readQuickBirthday(
  String line,
  DateTime today, {
  DayMonthOrder order = DayMonthOrder.dayFirst,
}) {
  final words = [
    for (final word in line.trim().split(_spaces))
      if (word.isNotEmpty) word,
  ];
  if (words.isEmpty) {
    return const QuickBirthday(fullName: '', date: BirthDateEmpty());
  }

  final candidates = [
    ..._datesAt(words, today, order, atEnd: true),
    ..._datesAt(words, today, order, atEnd: false),
  ];
  if (candidates.isEmpty) {
    return QuickBirthday(
      fullName: _cleanName(words, dateAtEnd: true),
      date: const BirthDateEmpty(),
      source: words.join(' '),
    );
  }
  QuickBirthday reading(_Found found) {
    final rest = found.atEnd
        ? words.sublist(0, words.length - found.length)
        : words.sublist(found.length);
    return QuickBirthday(
      fullName: _cleanName(rest, dateAtEnd: found.atEnd),
      date: found.input,
      source: words.join(' '),
    );
  }

  // La lecture la plus longue qui laisse un nom : « Léa 12 » est Léa, le 12
  // d'un mois à venir. Un reste fait de mois n'est pas un nom : « 12 mars »
  // seul est une date sans nom, pas « mars » le 12.
  for (final found in candidates) {
    final candidate = reading(found);
    if (_isName(candidate.fullName)) return candidate;
  }
  return reading(candidates.first);
}

/// Lit chaque ligne non vide de [text], dans l'ordre.
List<QuickBirthday> readQuickBirthdays(
  String text,
  DateTime today, {
  DayMonthOrder order = DayMonthOrder.dayFirst,
}) => [
  for (final line in text.split('\n'))
    if (line.trim().isNotEmpty) readQuickBirthday(line, today, order: order),
];

/// Plusieurs lignes collées d'un coup, prêtes à ajouter : les nouvelles
/// personnes, celles qu'AnKi connaît déjà, et les lignes illisibles.
class const QuickBatch({
  /// Personnes à ajouter, dans l'ordre des lignes, chacune une fois.
  required final List<QuickBirthday> fresh,

  /// Personnes déjà dans AnKi (ou en double dans les lignes) : écartées.
  required final List<QuickBirthday> known,

  /// Lignes sans nom ou sans date complète : écartées.
  required final List<QuickBirthday> unreadable,
}) {
  @override
  bool operator ==(Object other) =>
      other is QuickBatch &&
      listEquals(other.fresh, fresh) &&
      listEquals(other.known, known) &&
      listEquals(other.unreadable, unreadable);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(fresh),
    Object.hashAll(known),
    Object.hashAll(unreadable),
  );
}

/// Trie [lines] comme l'import des contacts ([personKey]) : une personne
/// déjà dans [existing], ou déjà vue plus haut, est écartée.
QuickBatch previewQuickBatch(
  List<QuickBirthday> lines, {
  required List<Birthday> existing,
}) {
  final seen = {
    for (final birthday in existing)
      personKey(birthday.fullName, birthday.date),
  };
  final fresh = <QuickBirthday>[];
  final known = <QuickBirthday>[];
  final unreadable = <QuickBirthday>[];
  for (final line in lines) {
    if (line.date case BirthDateComplete(:final date) when line.isReady) {
      (seen.add(personKey(line.fullName, date)) ? fresh : known).add(line);
    } else {
      unreadable.add(line);
    }
  }
  return QuickBatch(fresh: fresh, known: known, unreadable: unreadable);
}

/// La personne de [line] est déjà dans [existing] : même nom (aux
/// majuscules et accents près), même jour, même mois.
bool isKnownBirthday(QuickBirthday line, List<Birthday> existing) {
  if (line.date case BirthDateComplete(:final date) when line.isReady) {
    final key = personKey(line.fullName, date);
    return existing.any(
      (birthday) => personKey(birthday.fullName, birthday.date) == key,
    );
  }
  return false;
}

// ─── Lecture de la date ──────────────────────────────────────────────────────

/// Une date trouvée : sa lecture, le nombre de mots qu'elle occupe, et si
/// elle finit la ligne (sinon elle l'ouvre).
typedef _Found = ({BirthDateInput input, int length, bool atEnd});

/// Dates qui finissent ([atEnd]) ou ouvrent la ligne, de la plus longue à la
/// plus courte.
Iterable<_Found> _datesAt(
  List<String> words,
  DateTime today,
  DayMonthOrder order, {
  required bool atEnd,
}) sync* {
  for (var length = 3; length >= 1; length--) {
    if (length > words.length) continue;
    final slice = atEnd
        ? words.sublist(words.length - length)
        : words.sublist(0, length);
    final input = _readDate(slice, today, order, atEnd: atEnd);
    if (input != null) yield (input: input, length: length, atEnd: atEnd);
  }
}

/// Lit [words] comme une date entière, ou null. En fin de ligne ([atEnd]),
/// un mois en cours de frappe (« 12 m ») donne une saisie inachevée.
BirthDateInput? _readDate(
  List<String> words,
  DateTime today,
  DayMonthOrder order, {
  required bool atEnd,
}) {
  final tokens = [for (final word in words) _trimPunctuation(word)];
  if (tokens.any((token) => token.isEmpty)) return null;
  switch (tokens) {
    case [final numeric] when _numeric.hasMatch(numeric):
      return _readNumeric(numeric, today, order);
    case [final day, final month] when _isDay(day) && _month(month) != null:
      return _complete(_day(day), _month(month)!, null, today);
    case [final month, final day] when _month(month) != null && _isDay(day):
      return _complete(_day(day), _month(month)!, null, today);
    case [final day, final month, final year]
        when _isDay(day) && _month(month) != null && _isYear(year):
      return _complete(_day(day), _month(month)!, year, today);
    case [final month, final day, final year]
        when _month(month) != null && _isDay(day) && _isYear(year):
      return _complete(_day(day), _month(month)!, year, today);
    case [final day, final month, final year]
        when _isDay(day) && _month(month) != null && _isNumber(year):
      // « 12 mars 199 » : l'année n'a pas encore ses chiffres.
      return const BirthDateInvalid(BirthDateError.incompleteYear);
    case [final month, final day, final year]
        when _month(month) != null && _isDay(day) && _isNumber(year):
      return const BirthDateInvalid(BirthDateError.incompleteYear);
    case [final day, final typing]
        when atEnd && _isDay(day) && _isMonthPrefix(typing):
      // « 12 m » : le mois est en cours de frappe.
      return const BirthDateIncomplete();
  }
  return null;
}

/// Date en chiffres, « 12/03 », « 3/2/50 », « 1203 » : l'année sur deux
/// chiffres est complétée, puis [parseBirthDate] lit le reste.
BirthDateInput _readNumeric(String text, DateTime today, DayMonthOrder order) {
  final parts = _digitsOnly.hasMatch(text)
      ? _fixedWidthParts(text)
      : text.split(_separators);
  if (parts.length == 3 && parts[2].length == 2 && parts.every(_isNumber)) {
    final (dayText, monthText) = switch (order) {
      DayMonthOrder.dayFirst => (parts[0], parts[1]),
      DayMonthOrder.monthFirst => (parts[1], parts[0]),
    };
    final year = _fullYear(
      int.parse(parts[2]),
      int.parse(monthText),
      int.parse(dayText),
      today,
    );
    return parseBirthDate('${parts[0]}/${parts[1]}/$year', today, order: order);
  }
  return parseBirthDate(parts.join('/'), today, order: order);
}

/// Jour et mois connus, année facultative : la lecture de [parseBirthDate],
/// qui sait refuser le 31 avril ou une date à venir.
BirthDateInput _complete(int day, int month, String? year, DateTime today) {
  final fullYear = switch (year) {
    null => null,
    final text when text.length == 2 => _fullYear(
      int.parse(text),
      month,
      day,
      today,
    ),
    final text => int.parse(text),
  };
  return parseBirthDate([day, month, ?fullYear].join('/'), today);
}

/// Année d'une année sur deux chiffres : le siècle le plus récent où le
/// jour n'est pas après [today].
int _fullYear(int twoDigits, int month, int day, DateTime today) {
  final recent = 2000 + twoDigits;
  final date = DateTime(recent, month, day);
  final now = DateTime(today.year, today.month, today.day);
  return date.isAfter(now) ? 1900 + twoDigits : recent;
}

/// « 1203 » → « 12 », « 03 » ; « 120350 » → « 12 », « 03 », « 50 » ; au-delà,
/// l'année entière.
List<String> _fixedWidthParts(String digits) => [
  digits.substring(0, digits.length < 2 ? digits.length : 2),
  if (digits.length > 2) digits.substring(2, digits.length < 4 ? null : 4),
  if (digits.length > 4) digits.substring(4),
];

bool _isNumber(String text) => _digitsOnly.hasMatch(text);

bool _isDay(String token) => _dayPattern.hasMatch(token);

int _day(String token) => int.parse(_dayPattern.firstMatch(token)![1]!);

bool _isYear(String token) => _yearPattern.hasMatch(token);

/// Mois d'un mot, en français ou en anglais, entier ou abrégé (« mars »,
/// « févr. », « Sept », « March ») ; null sinon.
int? _month(String token) => _months[_foldWord(token)];

/// Début d'un nom de mois, en cours de frappe : « m », « ma », « nov ».
bool _isMonthPrefix(String token) {
  final folded = _foldWord(token);
  if (folded.isEmpty || !_letters.hasMatch(folded)) return false;
  return _monthNames.any((name) => name.startsWith(folded));
}

String _foldWord(String token) =>
    foldForMatching(token).replaceAll('.', '').replaceAll(' ', '');

/// Le mot sans la ponctuation qui l'entoure : « 12, » → « 12 », « (Léa) » →
/// « Léa ». Les séparateurs d'une date en chiffres restent.
String _trimPunctuation(String word) => word.replaceAll(_edgePunctuation, '');

// ─── Nom ─────────────────────────────────────────────────────────────────────

/// Le nom qui reste, sans ponctuation isolée ni « le » / « né le » / « on »
/// collé à la date.
String _cleanName(List<String> words, {required bool dateAtEnd}) {
  final kept = [
    for (final word in words)
      if (_trimPunctuation(word).isNotEmpty) _trimPunctuation(word),
  ];
  if (dateAtEnd) {
    while (kept.isNotEmpty) {
      final last = _foldWord(kept.last);
      final before = kept.length > 1 ? _foldWord(kept[kept.length - 2]) : '';
      if (_bornWords.contains(last)) {
        kept.removeLast();
      } else if ({'le', 'on'}.contains(last) && _bornWords.contains(before)) {
        // « née le », « Née Le » (le clavier met des majuscules), « born on ».
        kept
          ..removeLast()
          ..removeLast();
      } else if ({'le', 'on'}.contains(kept.last)) {
        // Seul, comparé tel que tapé : « Lê » et « Le » sont des noms.
        kept.removeLast();
      } else {
        break;
      }
    }
  }
  return kept.join(' ');
}

/// « Né », « née », « born », repliés : ils relient le nom à la date.
const _bornWords = {'ne', 'nee', 'born'};

final _spaces = RegExp(r'\s+');
final _numeric = RegExp(r'^[0-9]+([/.\-][0-9]*){0,2}$');
final _digitsOnly = RegExp(r'^[0-9]+$');
final _separators = RegExp(r'[/.\-]');
final _dayPattern = RegExp(r'^([0-9]{1,2})(er|re|st|nd|rd|th)?$');
final _yearPattern = RegExp(r'^([0-9]{2}|[0-9]{4})$');
final _letters = RegExp(r'^[a-z]+$');
final _edgePunctuation = RegExp(r'^[,;:()«»"“”–—]+|[,;:()«»"“”–—!?]+$');

/// Noms des mois, repliés ([foldForMatching]) et sans point, vers leur
/// numéro : français puis anglais, entiers et abrégés.
const _months = {
  'janvier': 1,
  'janv': 1,
  'jan': 1,
  'january': 1,
  'fevrier': 2,
  'fevr': 2,
  'fev': 2,
  'february': 2,
  'feb': 2,
  'mars': 3,
  'mar': 3,
  'march': 3,
  'avril': 4,
  'avr': 4,
  'april': 4,
  'apr': 4,
  'mai': 5,
  'may': 5,
  'juin': 6,
  'june': 6,
  'jun': 6,
  'juillet': 7,
  'juil': 7,
  'july': 7,
  'jul': 7,
  'aout': 8,
  'august': 8,
  'aug': 8,
  'septembre': 9,
  'sept': 9,
  'sep': 9,
  'september': 9,
  'octobre': 10,
  'oct': 10,
  'october': 10,
  'novembre': 11,
  'nov': 11,
  'november': 11,
  'decembre': 12,
  'dec': 12,
  'december': 12,
};

final _monthNames = _months.keys.toList(growable: false);

/// Un reste qui peut être un nom : pas vide, et pas seulement des mois.
bool _isName(String text) =>
    text.isNotEmpty && text.split(' ').any((word) => _month(word) == null);
