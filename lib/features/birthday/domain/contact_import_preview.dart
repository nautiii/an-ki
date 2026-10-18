import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:flutter/foundation.dart';

/// Anniversaires du répertoire proposés à l'import : les nouveaux, à cocher,
/// et ceux qu'AnKi connaît déjà, montrés à part pour ne pas les doubler.
class const ContactImportPreview({
  /// Personnes absentes d'AnKi, du plus proche anniversaire au plus lointain.
  required final List<BirthdayDraft> fresh,

  /// Personnes déjà dans AnKi, dans le même ordre : rien à importer.
  required final List<BirthdayDraft> known,
}) {
  @override
  bool operator ==(Object other) =>
      other is ContactImportPreview &&
      listEquals(other.fresh, fresh) &&
      listEquals(other.known, known);

  @override
  int get hashCode => Object.hash(Object.hashAll(fresh), Object.hashAll(known));
}

/// Prépare l'import de [contacts] : du plus proche anniversaire au plus
/// lointain à partir de [today] (puis par nom), chaque personne une seule
/// fois, et à part celles que [existing] contient déjà.
///
/// Même personne : même nom aux majuscules, accents, tirets et espaces près,
/// même jour et même mois — l'année manque souvent d'un côté ou de l'autre.
/// En double dans le répertoire, la fiche qui connaît l'année l'emporte. Un
/// contact sans prénom prend son nom comme prénom (« Dupont ») ; sans l'un ni
/// l'autre, il n'est pas proposé.
ContactImportPreview previewContactImport(
  List<BirthdayDraft> contacts, {
  required List<Birthday> existing,
  required DateTime today,
}) {
  final inAnKi = {
    for (final birthday in existing)
      _personKey(birthday.fullName, birthday.date),
  };
  final sorted = [for (final contact in contacts) ?_named(contact)]
    ..sort((a, b) {
      final byDay = a.date
          .daysUntilNext(today)
          .compareTo(b.date.daysUntilNext(today));
      if (byDay != 0) return byDay;
      final byName = _fold(a.fullName).compareTo(_fold(b.fullName));
      if (byName != 0) return byName;
      // Le même jour, sous le même nom : l'année connue d'abord.
      return (b.date.year ?? 0).compareTo(a.date.year ?? 0);
    });

  final seen = <String>{};
  final fresh = <BirthdayDraft>[];
  final known = <BirthdayDraft>[];
  for (final contact in sorted) {
    final key = _personKey(contact.fullName, contact.date);
    if (!seen.add(key)) continue;
    (inAnKi.contains(key) ? known : fresh).add(contact);
  }
  return ContactImportPreview(fresh: fresh, known: known);
}

/// [contact] aux noms nettoyés, son nom en prénom s'il n'a pas de prénom ;
/// null sans aucun nom.
BirthdayDraft? _named(BirthdayDraft contact) {
  final name = contact.name.trim();
  final surname = contact.surname.trim();
  if (name.isEmpty && surname.isEmpty) return null;
  return BirthdayDraft(
    name: name.isEmpty ? surname : name,
    surname: name.isEmpty ? '' : surname,
    date: contact.date,
  );
}

String _personKey(String fullName, BirthDate date) =>
    '${_fold(fullName)}|${date.month}|${date.day}';

/// [text] sans majuscules, accents ni tirets, les espaces réduits à un seul.
String _fold(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_plain[char] ?? char);
  }
  return buffer
      .toString()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .join(' ');
}

/// Lettres accentuées (et tiret) → leur forme simple.
const _plain = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'á': 'a',
  'ã': 'a',
  'å': 'a',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'œ': 'oe',
  'æ': 'ae',
  '-': ' ',
};
