import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';

/// Règles de dates d'une date de naissance.
///
/// [today] est toujours passé en paramètre (`todayProvider` côté providers et
/// widgets) : rien ici ne lit l'horloge, les tests fixent le jour. Seuls
/// l'année, le mois et le jour de [today] comptent.
extension BirthDateDates on BirthDate {
  /// Jour de l'anniversaire l'année [year].
  ///
  /// Né un 29 février : le 1er mars les années non bissextiles.
  DateTime occurrenceIn(int year) => DateTime(year, month, day);

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

  /// Âge atteint au prochain anniversaire à partir de [today], celui du jour
  /// compris : « aura 34 ans ». Null quand l'année de naissance est inconnue.
  int? turningAge(DateTime today) {
    final year = this.year;
    if (year == null) return null;
    return nextOccurrence(today).year - year;
  }

  /// Âge en années révolues à [today] ; l'anniversaire compte dès son jour.
  /// Null quand l'année de naissance est inconnue.
  int? ageOn(DateTime today) {
    final year = this.year;
    if (year == null) return null;
    final hadBirthday =
        today.month > month || (today.month == month && today.day >= day);
    return today.year - year - (hadBirthday ? 0 : 1);
  }
}

/// Les mêmes règles, lues depuis un anniversaire.
extension BirthdayDates on Birthday {
  /// Voir [BirthDateDates.occurrenceIn].
  DateTime occurrenceIn(int year) => date.occurrenceIn(year);

  /// Voir [BirthDateDates.nextOccurrence].
  DateTime nextOccurrence(DateTime today) => date.nextOccurrence(today);

  /// Voir [BirthDateDates.daysUntilNext].
  int daysUntilNext(DateTime today) => date.daysUntilNext(today);

  /// Voir [BirthDateDates.turningAge].
  int? turningAge(DateTime today) => date.turningAge(today);

  /// Voir [BirthDateDates.ageOn].
  int? ageOn(DateTime today) => date.ageOn(today);
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
