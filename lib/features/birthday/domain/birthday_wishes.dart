import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/domain/birthday_search.dart';

/// Règles du « souhaité » : quel anniversaire un vœu concerne, et s'il a été
/// fait. [today] est passé en paramètre, comme pour les autres règles de
/// dates.
extension BirthdayWishes on Birthday {
  /// Année de l'anniversaire qu'un vœu fait à [today] concerne : le dernier,
  /// ce jour compris. Le jour J, l'année en cours.
  int wishYear(DateTime today) => lastOccurrence(today).year;

  /// Vrai si l'anniversaire de [wishYear] a été souhaité.
  bool isWished(DateTime today) => wishedYears.contains(wishYear(today));

  /// Vrai le lendemain d'un anniversaire pas encore souhaité : il peut
  /// l'être encore, en retard, pour l'année de [wishYear]. Un 29 février
  /// fêté le 1er mars hors année bissextile l'est donc le 2.
  bool isBelated(DateTime today) =>
      lastOccurrence(today) ==
          DateTime(today.year, today.month, today.day - 1) &&
      !isWished(today);
}

/// Règles du « souhaité » sur une liste d'anniversaires.
extension BirthdayListWishes on Iterable<Birthday> {
  /// Anniversaires d'hier encore à souhaiter ([BirthdayWishes.isBelated]),
  /// par nom sans accents ni casse, puis par id : Firestore ne garantit aucun
  /// ordre d'une synchronisation à l'autre.
  List<Birthday> belated(DateTime today) =>
      [
        for (final birthday in this)
          if (birthday.isBelated(today)) birthday,
      ]..sort((a, b) {
        final byName = searchKey(a.fullName).compareTo(searchKey(b.fullName));
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });
}
