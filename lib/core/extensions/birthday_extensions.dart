import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/category_model.dart';
import 'package:flutter/material.dart';


extension BirthdayCategoryX on BirthdayCategory {
  String getLocalizedName(BuildContext context) {
    final n = name.toLowerCase();
    if (n == 'family') return context.l10n.family;
    if (n == 'friend') return context.l10n.friend;
    if (n == 'colleague') return context.l10n.colleague;
    if (n == 'other') return context.l10n.other;
    return name;
  }
}

extension BirthdayUpcoming on BirthdayModel {
  /// Prochain anniversaire (aujourd'hui ou futur).
  DateTime get nextOccurrence {
    final DateTime now = DateTime.now();
    final DateTime todayAtMidnight = DateTime(now.year, now.month, now.day);
    DateTime candidate = DateTime(now.year, date.month, date.day);

    // Si l'anniversaire est déjà passé strictement avant aujourd'hui cette année.
    if (candidate.isBefore(todayAtMidnight)) {
      candidate = DateTime(now.year + 1, date.month, date.day);
    }
    return candidate;
  }

  int get daysUntilNext {
    final DateTime today = DateTime.now();
    return nextOccurrence
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  /// Âge actuel du contact (ajusté si l'anniversaire n'est pas encore passé).
  int get age {
    final DateTime now = DateTime.now();
    int years = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      years--;
    }
    return years;
  }

  String getFormattedDate(BuildContext context, {bool includeYear = true}) {
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

extension BirthdaySection on List<BirthdayModel> {
  BirthdayModel? get nextBirthday {
    return isEmpty
        ? null
        : reduce(
          (BirthdayModel a, BirthdayModel b) =>
              a.daysUntilNext <= b.daysUntilNext ? a : b,
        );
  }
}
