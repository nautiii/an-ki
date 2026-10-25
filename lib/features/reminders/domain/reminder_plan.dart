import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';

/// Limites de la planification, indépendantes des préférences.
abstract final class ReminderPolicy {
  /// Rappels planifiés au plus : Android (12 et plus) refuse une alarme de
  /// plus au-delà de 500 par app, et le refus ne se voit pas. La marge laisse
  /// la place aux alarmes du système de notifications.
  static const maxScheduled = 450;
}

/// Rappel planifié pour un anniversaire.
class const PlannedReminder({
  /// Identifiant de la notification, unique dans le plan et stable d'une
  /// replanification à l'autre ; dérivé de l'anniversaire et du moment du
  /// rappel.
  required final int id,
  required final ReminderLead lead,

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
      other.lead == lead &&
      other.birthdayId == birthdayId &&
      other.name == name &&
      other.surname == surname &&
      other.age == age &&
      other.at == at;

  @override
  int get hashCode => Object.hash(id, lead, birthdayId, name, surname, age, at);
}

/// Rappels de chaque anniversaire selon [preferences] (et le réglage propre
/// de la personne), au prochain créneau encore à venir après [now] : un
/// créneau déjà passé cette année glisse à l'année suivante.
///
/// Au-delà de [ReminderPolicy.maxScheduled], les jours J passent d'abord,
/// puis la semaine, la veille et le mois avant ; à rang égal, les plus
/// proches.
List<PlannedReminder> planReminders(
  Iterable<Birthday> birthdays, {
  required DateTime now,
  ReminderPreferences preferences = const ReminderPreferences(),
}) {
  final slots = _notificationSlots(birthdays.map((b) => b.id));
  final plan = [
    for (final birthday in birthdays)
      for (final lead in preferences.leadsFor(birthday))
        _plan(birthday, lead, slots[birthday.id]!, now, preferences),
  ];
  if (plan.length <= ReminderPolicy.maxScheduled) return plan;
  return (plan..sort(_byPriority)).take(ReminderPolicy.maxScheduled).toList();
}

/// Ordre de sacrifice quand le plan déborde : le jour J reste le dernier à
/// tomber.
const _priority = [
  ReminderLead.sameDay,
  ReminderLead.weekBefore,
  ReminderLead.dayBefore,
  ReminderLead.monthBefore,
];

int _byPriority(PlannedReminder a, PlannedReminder b) {
  final byLead = _priority.indexOf(a.lead) - _priority.indexOf(b.lead);
  return byLead != 0 ? byLead : a.at.compareTo(b.at);
}

/// Prochain rappel du jour J après [now] — le premier que l'app enverra —,
/// ou null sans anniversaire rappelé. Deux le même jour : par ordre
/// alphabétique.
PlannedReminder? nextBirthdayReminder(
  Iterable<Birthday> birthdays, {
  required DateTime now,
  ReminderPreferences preferences = const ReminderPreferences(),
}) {
  PlannedReminder? next;
  for (final reminder in planReminders(
    birthdays,
    now: now,
    preferences: preferences,
  )) {
    if (reminder.lead != ReminderLead.sameDay) continue;
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
  ReminderLead lead,
  int slot,
  DateTime now,
  ReminderPreferences preferences,
) {
  var occurrence = birthday.nextOccurrence(now);
  var at = _reminderAt(occurrence, lead, preferences);
  if (at.isBefore(now)) {
    occurrence = DateTime(
      occurrence.year + 1,
      birthday.date.month,
      birthday.date.day,
    );
    at = _reminderAt(occurrence, lead, preferences);
  }
  return PlannedReminder(
    id: _notificationId(slot, lead),
    lead: lead,
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
/// l'heure choisie.
DateTime _reminderAt(
  DateTime occurrence,
  ReminderLead lead,
  ReminderPreferences preferences,
) => DateTime(
  occurrence.year,
  occurrence.month,
  occurrence.day - lead.days,
  preferences.hour,
  preferences.minute,
);

/// Nombre d'emplacements d'id : chaque moment de rappel a sa plage, décalée
/// d'un multiple de 100000, sans chevauchement. Le jour J et J-7 gardent
/// leurs plages d'avant B6 : les rappels déjà planifiés sur les téléphones
/// sont remplacés, pas dupliqués.
const _slotCount = 100000;

int _offset(ReminderLead lead) => switch (lead) {
  ReminderLead.sameDay => 0,
  ReminderLead.dayBefore => 100000,
  ReminderLead.monthBefore => 200000,
  ReminderLead.weekBefore => 500000,
};

/// Emplacement de départ d'un anniversaire. Même formule qu'avant
/// l'extraction : les rappels déjà planifiés sur les téléphones sont
/// remplacés, pas dupliqués.
int _naturalSlot(String birthdayId) => birthdayId.hashCode.abs() % _slotCount;

/// Attribue à chaque anniversaire un emplacement unique : deux anniversaires
/// sur le même emplacement s'écraseraient (`zonedSchedule` remplace la
/// notification de même id) et l'un perdrait ses rappels.
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
/// anniversaire et du moment du rappel.
int _notificationId(int slot, ReminderLead lead) => slot + _offset(lead);
