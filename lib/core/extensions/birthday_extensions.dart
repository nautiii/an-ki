import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/category_model.dart';
import 'package:flutter/material.dart';

const List<String> months = <String>[
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

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

  String get formattedDate =>
      '${date.day} ${months[date.month - 1]} ${date.year}';
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
