import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';

/// Moment d'un rappel par rapport à l'anniversaire.
enum ReminderKind {
  /// Le jour même.
  birthday,

  /// Une semaine avant, pour préparer un cadeau.
  weekBefore,
}

/// Politique de rappel actuelle : le jour J et sept jours avant, à 10 h
/// (heure locale). Les rappels personnalisés (backlog B6) la rendront
/// réglable.
abstract final class ReminderPolicy {
  static const hour = 10;
  static const daysBefore = 7;
}

/// Rappel planifié pour un anniversaire.
class const PlannedReminder({
  /// Identifiant de la notification, unique dans le plan et stable d'une
  /// replanification à l'autre ; dérivé de l'anniversaire et du type de
  /// rappel.
  required final int id,
  required final ReminderKind kind,

  /// Anniversaire rappelé : le toucher de la notification y ramène.
  required final String birthdayId,
  required final String name,
  required final String surname,

  /// Âge atteint le jour de l'anniversaire ; null quand l'année de naissance
  /// est inconnue.
  required final int? age,

  /// Moment du rappel, heure locale.
  required final DateTime at,
}) {
  /// Prénom et nom réunis, sans espace de trop quand l'un manque
  /// (« Mamie »), comme dans la notification.
  String get fullName =>
      [name, surname].where((part) => part.isNotEmpty).join(' ');

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.kind == kind &&
      other.birthdayId == birthdayId &&
      other.name == name &&
      other.surname == surname &&
      other.age == age &&
      other.at == at;

  @override
  int get hashCode => Object.hash(id, kind, birthdayId, name, surname, age, at);
}

/// Rappels de chaque anniversaire (jour J et J-7), au prochain créneau encore
/// à venir après [now] : un créneau déjà passé cette année glisse à l'année
/// suivante.
List<PlannedReminder> planReminders(
  Iterable<Birthday> birthdays, {
  required DateTime now,
}) {
  final slots = _notificationSlots(birthdays.map((b) => b.id));
  return [
    for (final birthday in birthdays)
      for (final kind in ReminderKind.values)
        _plan(birthday, kind, slots[birthday.id]!, now),
  ];
}

/// Prochain rappel du jour J après [now] — le premier que l'app enverra —,
/// ou null sans anniversaire. Deux le même jour : par ordre alphabétique.
PlannedReminder? nextBirthdayReminder(
  Iterable<Birthday> birthdays, {
  required DateTime now,
}) {
  PlannedReminder? next;
  for (final reminder in planReminders(birthdays, now: now)) {
    if (reminder.kind != ReminderKind.birthday) continue;
    if (next == null ||
        reminder.at.isBefore(next.at) ||
        (reminder.at == next.at &&
            reminder.fullName.compareTo(next.fullName) < 0)) {
      next = reminder;
    }
  }
  return next;
}

PlannedReminder _plan(
  Birthday birthday,
  ReminderKind kind,
  int slot,
  DateTime now,
) {
  final daysBefore = switch (kind) {
    ReminderKind.birthday => 0,
    ReminderKind.weekBefore => ReminderPolicy.daysBefore,
  };
  var occurrence = birthday.nextOccurrence(now);
  var at = _reminderAt(occurrence, daysBefore);
  if (at.isBefore(now)) {
    occurrence = DateTime(
      occurrence.year + 1,
      birthday.date.month,
      birthday.date.day,
    );
    at = _reminderAt(occurrence, daysBefore);
  }
  return PlannedReminder(
    id: _notificationId(slot, kind),
    kind: kind,
    birthdayId: birthday.id,
    name: birthday.name,
    surname: birthday.surname,
    age: switch (birthday.date.year) {
      final year? => occurrence.year - year,
      null => null,
    },
    at: at,
  );
}

/// Jour du rappel compté en jours de calendrier — des tranches de 24 h
/// décaleraient d'un jour un rappel qui enjambe un changement d'heure — à
/// l'heure de la politique.
DateTime _reminderAt(DateTime occurrence, int daysBefore) => DateTime(
  occurrence.year,
  occurrence.month,
  occurrence.day - daysBefore,
  ReminderPolicy.hour,
);

/// Nombre d'emplacements d'id : le J-7 prend `emplacement + 500000`, les
/// deux plages ne se chevauchent pas.
const _slotCount = 100000;
const _weekBeforeOffset = 500000;

/// Emplacement de départ d'un anniversaire. Même formule qu'avant
/// l'extraction : les rappels déjà planifiés sur les téléphones sont
/// remplacés, pas dupliqués.
int _naturalSlot(String birthdayId) => birthdayId.hashCode.abs() % _slotCount;

/// Attribue à chaque anniversaire un emplacement unique : deux anniversaires
/// sur le même emplacement s'écraseraient (`zonedSchedule` remplace la
/// notification de même id) et l'un perdrait ses deux rappels.
///
/// Déterministe et aussi stable que possible :
/// 1. chaque emplacement naturel revient au plus petit id qui le vise, donc
///    un anniversaire sans collision garde toujours son id historique ;
/// 2. les perdants, triés par id, sondent linéairement les emplacements
///    suivants (en bouclant) jusqu'au premier libre.
/// Seuls les perdants d'une collision peuvent changer d'id d'une liste à
/// l'autre ; le balayage de `NotificationService.scheduleAll` annule alors
/// l'ancien.
Map<String, int> _notificationSlots(Iterable<String> birthdayIds) {
  final ids = birthdayIds.toSet().toList()..sort();
  if (ids.length > _slotCount) {
    throw StateError('More than $_slotCount birthdays to remind.');
  }
  final slots = <String, int>{};
  final taken = <int>{};
  final losers = <String>[];
  for (final id in ids) {
    final slot = _naturalSlot(id);
    if (taken.add(slot)) {
      slots[id] = slot;
    } else {
      losers.add(id);
    }
  }
  for (final id in losers) {
    var slot = _naturalSlot(id);
    while (!taken.add(slot)) {
      slot = (slot + 1) % _slotCount;
    }
    slots[id] = slot;
  }
  return slots;
}

/// Id entier (le plugin l'exige) d'un rappel, dérivé de l'emplacement de son
/// anniversaire et de son type.
int _notificationId(int slot, ReminderKind kind) => switch (kind) {
  ReminderKind.birthday => slot,
  ReminderKind.weekBefore => slot + _weekBeforeOffset,
};
