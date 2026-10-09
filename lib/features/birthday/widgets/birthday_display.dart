import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/domain/birthday_model.dart';
import 'package:flutter/widgets.dart';

/// Rendu d'un [BirthdayModel] : textes affichés.
extension BirthdayDisplay on BirthdayModel {
  /// Date de naissance « 10 Janvier 1990 », ou « 10 Janvier » sans l'année.
  String formattedDate(BuildContext context, {bool includeYear = true}) {
    final monthKeys = [
      context.l10n.january,
      context.l10n.february,
      context.l10n.march,
      context.l10n.april,
      context.l10n.may,
      context.l10n.june,
      context.l10n.july,
      context.l10n.august,
      context.l10n.september,
      context.l10n.october,
      context.l10n.november,
      context.l10n.december,
    ];
    final dateString = '${date.day} ${monthKeys[date.month - 1]}';
    return includeYear ? '$dateString ${date.year}' : dateString;
  }
}
