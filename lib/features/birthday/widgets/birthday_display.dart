import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Rendu d'un [Birthday] : textes affichés.
extension BirthdayDisplay on Birthday {
  /// Date de naissance dans la langue de l'app : « 10 janvier 1990 », ou
  /// « 10 janvier » sans l'année.
  String formattedDate(BuildContext context, {bool includeYear = true}) {
    final locale = Localizations.localeOf(context).languageCode;
    final format = includeYear
        ? DateFormat.yMMMMd(locale)
        : DateFormat.MMMMd(locale);
    return format.format(DateTime(date.year, date.month, date.day));
  }
}
