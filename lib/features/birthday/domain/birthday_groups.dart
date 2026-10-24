import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_search.dart';

/// Groupes proposés à tous avant les siens : Famille, Amis, Travail.
const _leadingDefaults = ['family', 'friend', 'colleague'];

/// Groupe proposé à tous après les siens : Autres.
const _trailingDefault = 'other';

/// Noms des catégories prédéfinies (collection partagée) proposées à tous
/// comme groupes, dans leur ordre d'affichage.
const defaultGroupNames = [..._leadingDefaults, _trailingDefault];

/// Groupes de l'utilisateur, dans l'ordre de leur ligne de puces : Famille,
/// Amis et Travail, puis les siens par nom — catégories partagées choisies
/// autrefois ([pickedIds] parmi [shared]) et groupes privés ([own]) —,
/// « Autres » en dernier. Un groupe par défaut absent de [shared] (pas encore
/// chargé) est omis ; un même id n'apparaît qu'une fois.
List<BirthdayCategory> userGroups({
  required Iterable<BirthdayCategory> shared,
  Iterable<String> pickedIds = const [],
  Iterable<BirthdayCategory> own = const [],
}) {
  final defaults = <String, BirthdayCategory>{};
  for (final category in shared) {
    final name = category.name.toLowerCase();
    if (defaultGroupNames.contains(name)) {
      defaults.putIfAbsent(name, () => category);
    }
  }
  final seen = {for (final category in defaults.values) category.id};
  final picked = pickedIds.toSet();
  final mine = [
    for (final category in [
      ...shared.where((category) => picked.contains(category.id)),
      ...own,
    ])
      if (seen.add(category.id)) category,
  ]..sort((a, b) => searchKey(a.name).compareTo(searchKey(b.name)));

  return [
    for (final name in _leadingDefaults) ?defaults[name],
    ...mine,
    ?defaults[_trailingDefault],
  ];
}

/// Groupes à proposer comme filtres de la recherche : parmi [groups], ceux
/// que portent des anniversaires et ceux déjà choisis ([selected]), dans
/// l'ordre de [groups]. Aucun tant qu'un seul groupe sert et que rien n'est
/// choisi : filtrer ne départagerait personne.
List<BirthdayCategory> groupFilters(
  Iterable<BirthdayCategory> groups,
  Iterable<Birthday> birthdays, {
  Iterable<String> selected = const [],
}) {
  final used = {for (final birthday in birthdays) ...birthday.categories};
  final chosen = selected.toSet();
  final filters = [
    for (final group in groups)
      if (used.contains(group.id) || chosen.contains(group.id)) group,
  ];
  final usedCount = filters.where((group) => used.contains(group.id)).length;
  return usedCount >= 2 || chosen.isNotEmpty ? filters : const [];
}

/// Teinte proposée pour un nouveau groupe : la première de [palette] qu'aucun
/// groupe n'a ([used]) ; toutes prises, la palette recommence.
int firstFreeTone(Iterable<int> used, List<int> palette) {
  final taken = used.toSet();
  for (final tone in palette) {
    if (!taken.contains(tone)) return tone;
  }
  return palette[used.length % palette.length];
}

/// Ce qui empêche de créer un groupe sous un nom.
enum GroupNameIssue { empty, taken }

/// Problème du nom [input] d'un nouveau groupe, face aux noms affichés des
/// groupes existants ([existing]) comparés sans casse ni accents ; null s'il
/// convient.
GroupNameIssue? groupNameIssue(String input, Iterable<String> existing) {
  final key = searchKey(input);
  if (key.isEmpty) return GroupNameIssue.empty;
  return existing.any((name) => searchKey(name) == key)
      ? GroupNameIssue.taken
      : null;
}
