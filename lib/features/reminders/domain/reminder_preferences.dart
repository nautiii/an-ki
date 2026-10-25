import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:flutter/foundation.dart';

/// Réglage par défaut des rappels, choisi dans Réglages › Rappels : quand
/// prévenir avant chaque anniversaire, et à quelle heure (locale). Le jour J
/// est toujours prévenu.
///
/// Sans réglage enregistré : sept jours avant et le jour J, à 10 h — les
/// rappels d'avant B6.
class const ReminderPreferences({
  final Set<ReminderLead> leads = const {
    ReminderLead.weekBefore,
    ReminderLead.sameDay,
  },
  final int hour = 10,
  final int minute = 0,
}) {
  /// Rappels d'un anniversaire, du plus tôt au jour J : son réglage propre
  /// ([Birthday.reminders]) s'il en a un, sinon celui-ci. Le jour J en fait
  /// toujours partie, sauf pour un anniversaire sans rappel.
  List<ReminderLead> leadsFor(Birthday birthday) {
    final chosen = birthday.reminders ?? leads;
    if (birthday.reminders case final own? when own.isEmpty) return const [];
    return [
      for (final lead in ReminderLead.values)
        if (lead == ReminderLead.sameDay || chosen.contains(lead)) lead,
    ];
  }

  /// Rappel le plus tôt avant le jour J (« 7 jours avant »), null si seul le
  /// jour J est prévenu.
  ReminderLead? get earliestLead {
    for (final lead in ReminderLead.values) {
      if (lead != ReminderLead.sameDay && leads.contains(lead)) return lead;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderPreferences &&
      setEquals(other.leads, leads) &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(leads), hour, minute);
}
