import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Rendu d'un [Birthday] : textes affichés.
extension BirthdayDisplay on Birthday {
  /// Date de naissance dans la langue de l'app : « 10 janvier 1990 », ou
  /// « 10 janvier » sans [includeYear] ou quand l'année est inconnue.
  String formattedDate(BuildContext context, {bool includeYear = true}) {
    final locale = Localizations.localeOf(context).languageCode;
    final year = includeYear ? date.year : null;
    final format = year != null
        ? DateFormat.yMMMMd(locale)
        : DateFormat.MMMMd(locale);
    // Sans année, une année bissextile quelconque : le 29 février existe.
    return format.format(DateTime(year ?? 2000, date.month, date.day));
  }
}
