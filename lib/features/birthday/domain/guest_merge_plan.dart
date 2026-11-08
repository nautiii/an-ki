import 'package:an_ki/core/text/text_folding.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/contact_import_preview.dart';
import 'package:flutter/foundation.dart';

/// Ce que devient l'agenda d'un invité dans le compte Google qu'il ouvre
/// (B5.5) : ses anniversaires passent au compte, sauf ceux que le compte
/// connaît déjà ; ses groupes rejoignent ceux du compte de même nom, ou y
/// sont recréés.
class const GuestMergePlan({
  /// Anniversaires de l'invité repris par le compte : id → ses groupes, ceux
  /// de l'invité remplacés par leurs équivalents du compte.
  required final Map<String, List<String>> moves,

  /// Anniversaires de l'invité que le compte a déjà (même personne), ou qu'il
  /// avait lui-même en double : effacés, la fiche gardée l'emporte.
  required final List<String> duplicates,

  /// Groupes de l'invité sans équivalent dans le compte : recréés chez lui,
  /// sous leur id.
  required final List<BirthdayCategory> newGroups,
}) {
  @override
  bool operator ==(Object other) =>
      other is GuestMergePlan &&
      other.moves.length == moves.length &&
      moves.entries.every(
        (move) => listEquals(other.moves[move.key], move.value),
      ) &&
      listEquals(other.duplicates, duplicates) &&
      listEquals(other.newGroups, newGroups);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(moves.keys),
    Object.hashAll(duplicates),
    Object.hashAll(newGroups),
  );
}

/// Prépare la reprise par un compte ([target], ses groupes [targetGroups])
/// des anniversaires [guest] d'un invité et de ses groupes [guestGroups].
///
/// Même personne : la règle de l'import ([personKey]). Même groupe : même nom
/// replié ([foldForMatching]). Un groupe prédéfini, ou inconnu de l'invité,
/// garde son id.
GuestMergePlan planGuestMerge({
  required List<Birthday> guest,
  required List<BirthdayCategory> guestGroups,
  required List<Birthday> target,
  required List<BirthdayCategory> targetGroups,
}) {
  final targetGroupIds = {
    for (final group in targetGroups) foldForMatching(group.name): group.id,
  };
  final groupIds = <String, String>{};
  final newGroups = <BirthdayCategory>[];
  for (final group in guestGroups) {
    if (targetGroupIds[foldForMatching(group.name)] case final same?) {
      groupIds[group.id] = same;
    } else {
      newGroups.add(group);
    }
  }

  final known = {
    for (final birthday in target) personKey(birthday.fullName, birthday.date),
  };
  final moves = <String, List<String>>{};
  final duplicates = <String>[];
  for (final birthday in guest) {
    // Deux fiches de l'invité pour la même personne : la seconde est un
    // doublon de la première.
    if (!known.add(personKey(birthday.fullName, birthday.date))) {
      duplicates.add(birthday.id);
      continue;
    }
    moves[birthday.id] = {
      for (final id in birthday.categories) groupIds[id] ?? id,
    }.toList();
  }
  return GuestMergePlan(
    moves: moves,
    duplicates: duplicates,
    newGroups: newGroups,
  );
}
