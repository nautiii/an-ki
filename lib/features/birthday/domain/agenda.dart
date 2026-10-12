import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:flutter/foundation.dart';

/// Jours couverts par la première section de l'agenda.
const int agendaSoonDays = 7;

/// Période d'une section de l'agenda : les [agendaSoonDays] prochains jours,
/// puis un mois de calendrier.
sealed class AgendaPeriod {
  const AgendaPeriod();
}

/// Les anniversaires des [agendaSoonDays] prochains jours.
final class AgendaSoon extends AgendaPeriod {
  const AgendaSoon();

  @override
  bool operator ==(Object other) => other is AgendaSoon;

  @override
  int get hashCode => (AgendaSoon).hashCode;
}

/// Un mois de calendrier, au-delà des [agendaSoonDays] prochains jours.
final class AgendaMonth extends AgendaPeriod {
  const AgendaMonth(this.year, this.month);

  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      other is AgendaMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// Une section de l'agenda : sa période et ses anniversaires, du plus proche
/// au plus lointain.
class const AgendaSection({
  required final AgendaPeriod period,
  required final List<Birthday> birthdays,
}) {
  @override
  bool operator ==(Object other) =>
      other is AgendaSection &&
      other.period == period &&
      listEquals(other.birthdays, birthdays);

  @override
  int get hashCode => Object.hash(period, Object.hashAll(birthdays));
}

/// Règle de l'agenda sur une liste d'anniversaires.
extension BirthdayAgenda on Iterable<Birthday> {
  /// L'agenda à partir de [today] : les [agendaSoonDays] prochains jours,
  /// puis un mois par section, dans l'ordre chronologique. Un mois sans
  /// anniversaire n'a pas de section ; le mois en cours peut revenir l'année
  /// suivante, pour les jours déjà passés.
  List<AgendaSection> agenda(DateTime today) {
    final sections = <AgendaPeriod, List<Birthday>>{};
    for (final birthday in sortedByNext(today)) {
      final next = birthday.nextOccurrence(today);
      final period = birthday.daysUntilNext(today) <= agendaSoonDays
          ? const AgendaSoon()
          : AgendaMonth(next.year, next.month);
      (sections[period] ??= []).add(birthday);
    }
    return [
      for (final MapEntry(key: period, value: birthdays) in sections.entries)
        AgendaSection(period: period, birthdays: birthdays),
    ];
  }
}
