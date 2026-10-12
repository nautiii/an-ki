import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Rendu d'une [BirthDate] : textes affichés.
extension BirthDateDisplay on BirthDate {
  /// La date dans la langue de l'app : « 10 janvier 1990 », ou « 10 janvier »
  /// sans [includeYear] ou quand l'année est inconnue.
  String formatted(BuildContext context, {bool includeYear = true}) {
    final locale = Localizations.localeOf(context).languageCode;
    final year = includeYear ? this.year : null;
    final format = year != null
        ? DateFormat.yMMMMd(locale)
        : DateFormat.MMMMd(locale);
    // Sans année, une année bissextile quelconque : le 29 février existe.
    return format.format(DateTime(year ?? 2000, month, day));
  }
}

/// Rendu d'un [Birthday] : textes affichés.
extension BirthdayDisplay on Birthday {
  /// Date de naissance, voir [BirthDateDisplay.formatted].
  String formattedDate(BuildContext context, {bool includeYear = true}) =>
      date.formatted(context, includeYear: includeYear);
}
