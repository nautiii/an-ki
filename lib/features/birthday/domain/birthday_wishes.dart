import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';

/// Règles du « souhaité » : quel anniversaire un vœu concerne, et s'il a été
/// fait. [today] est passé en paramètre, comme pour les autres règles de
/// dates.
extension BirthdayWishes on Birthday {
  /// Année de l'anniversaire qu'un vœu fait à [today] concerne : le dernier,
  /// ce jour compris. Le jour J, l'année en cours.
  int wishYear(DateTime today) => lastOccurrence(today).year;

  /// Vrai si l'anniversaire de [wishYear] a été souhaité.
  bool isWished(DateTime today) => wishedYears.contains(wishYear(today));
}
