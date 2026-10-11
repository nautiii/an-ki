import 'package:an_ki/features/birthday/domain/birthday.dart';

/// Règles de dates d'un anniversaire.
///
/// [today] est toujours passé en paramètre (`todayProvider` côté providers et
/// widgets) : rien ici ne lit l'horloge, les tests fixent le jour. Seuls
/// l'année, le mois et le jour de [today] comptent.
extension BirthdayDates on Birthday {
  /// Jour de l'anniversaire l'année [year].
  ///
  /// Né un 29 février : le 1er mars les années non bissextiles.
  DateTime occurrenceIn(int year) => DateTime(year, date.month, date.day);

  /// Prochain anniversaire à partir de [today], ce jour compris.
  DateTime nextOccurrence(DateTime today) {
    final day = _dayOf(today);
    final thisYear = occurrenceIn(day.year);
    if (!thisYear.isBefore(day)) return thisYear;
    return occurrenceIn(day.year + 1);
  }

  /// Jours avant le prochain anniversaire : 0 le jour même.
  ///
  /// Compté en jours de calendrier (dates UTC) : entre deux minuits locaux,
  /// un passage à l'heure d'été retire une heure et ferait perdre un jour.
  int daysUntilNext(DateTime today) =>
      _utcDay(nextOccurrence(today)).difference(_utcDay(today)).inDays;

  /// Âge en années révolues à [today] ; l'anniversaire compte dès son jour.
  int ageOn(DateTime today) {
    final hadBirthday =
        today.month > date.month ||
        (today.month == date.month && today.day >= date.day);
    return today.year - date.year - (hadBirthday ? 0 : 1);
  }
}

/// Règles de dates sur une liste d'anniversaires.
extension BirthdayListDates on Iterable<Birthday> {
  /// Anniversaires du plus proche au plus lointain à partir de [today].
  List<Birthday> sortedByNext(DateTime today) => toList()
    ..sort((a, b) => a.daysUntilNext(today).compareTo(b.daysUntilNext(today)));

  /// Le ou les prochains anniversaires à partir de [today] : plusieurs s'ils
  /// tombent le même jour, aucun pour une liste vide.
  List<Birthday> nextBirthdays(DateTime today) {
    if (isEmpty) return const [];
    final soonest = map((b) => b.daysUntilNext(today))
        .reduce((a, b) => a < b ? a : b);
    return where((b) => b.daysUntilNext(today) == soonest).toList();
  }
}

DateTime _dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

DateTime _utcDay(DateTime moment) =>
    DateTime.utc(moment.year, moment.month, moment.day);
