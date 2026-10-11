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
  /// Identifiant stable de la notification, dérivé de l'anniversaire et du
  /// type de rappel.
  required final int id,
  required final ReminderKind kind,
  required final String name,
  required final String surname,

  /// Âge atteint le jour de l'anniversaire.
  required final int age,

  /// Moment du rappel, heure locale.
  required final DateTime at,
}) {
  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.kind == kind &&
      other.name == name &&
      other.surname == surname &&
      other.age == age &&
      other.at == at;

  @override
  int get hashCode => Object.hash(id, kind, name, surname, age, at);
}

/// Rappels de chaque anniversaire (jour J et J-7), au prochain créneau encore
/// à venir après [now] : un créneau déjà passé cette année glisse à l'année
/// suivante.
List<PlannedReminder> planReminders(
  Iterable<Birthday> birthdays, {
  required DateTime now,
}) => [
  for (final birthday in birthdays)
    for (final kind in ReminderKind.values) _plan(birthday, kind, now),
];

PlannedReminder _plan(Birthday birthday, ReminderKind kind, DateTime now) {
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
    id: _notificationId(birthday.id, kind),
    kind: kind,
    name: birthday.name,
    surname: birthday.surname,
    age: occurrence.year - birthday.date.year,
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

/// Id entier (le plugin l'exige) stable pour un anniversaire et un type de
/// rappel. Même formule qu'avant l'extraction : les rappels déjà planifiés sur
/// les téléphones sont remplacés, pas dupliqués.
int _notificationId(String birthdayId, ReminderKind kind) {
  final base = birthdayId.hashCode.abs() % 100000;
  return switch (kind) {
    ReminderKind.birthday => base,
    ReminderKind.weekBefore => base + 500000,
  };
}
