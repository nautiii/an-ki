import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:flutter/material.dart';

extension BirthdayCategoryX on BirthdayCategory {
  String label(BuildContext context) {
    switch (this) {
      case BirthdayCategory.family:
        return context.l10n.family;
      case BirthdayCategory.friend:
        return context.l10n.friend;
      case BirthdayCategory.colleague:
        return context.l10n.colleague;
      case BirthdayCategory.other:
        return context.l10n.other;
    }
  }

  IconData get icon {
    switch (this) {
      case BirthdayCategory.family:
        return Icons.group_outlined;
      case BirthdayCategory.friend:
        return Icons.people_outline_rounded;
      case BirthdayCategory.colleague:
        return Icons.work_outline_rounded;
      case BirthdayCategory.other:
        return Icons.category_outlined;
    }
  }
}

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

extension BirthdayUpcoming on BirthdayModel {
  /// Prochain anniversaire cette année ou l'année suivante si déjà passé.
  DateTime get nextOccurrence {
    final DateTime today = DateTime.now();
    DateTime candidate = DateTime(today.year, date.month, date.day);
    if (!candidate.isAfter(DateTime(today.year, today.month, today.day))) {
      candidate = DateTime(today.year + 1, date.month, date.day);
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

extension BirthdayCategoryParser on String {
  BirthdayCategory toBirthdayCategory() {
    return BirthdayCategory.values.firstWhere(
      (BirthdayCategory category) => category.name == this,
      orElse: () => BirthdayCategory.other,
    );
  }
}
