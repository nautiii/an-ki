import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/data/models/category_model.dart';
import 'package:flutter/material.dart';

extension BirthdayCategoryX on BirthdayCategory {
  String getLocalizedName(BuildContext context) {
    final n = name.toLowerCase();
    if (n == 'family') return context.l10n.family;
    if (n == 'friend') return context.l10n.friend;
    if (n == 'colleague') return context.l10n.colleague;
    if (n == 'sport') return context.l10n.sport;
    if (n == 'school') return context.l10n.school;
    if (n == 'ogs') return context.l10n.ogs;
    if (n == 'gaming') return context.l10n.gaming;
    if (n == 'goat') return context.l10n.goat;
    if (n == 'doggo') return context.l10n.doggo;
    if (n == 'internet') return context.l10n.internet;
    if (n == 'bff') return context.l10n.bff;
    if (n == 'celebrity') return context.l10n.celebrity;
    if (n == 'favorite') return context.l10n.favorite;
    if (n == 'couple') return context.l10n.couple;
    if (n == 'other') return context.l10n.other;
    return name;
  }

  Color get color {
    final n = name.toLowerCase();
    if (n == 'family') return Colors.blue;
    if (n == 'friend') return Colors.green;
    if (n == 'colleague') return Colors.orange;
    if (n == 'sport') return Colors.red;
    if (n == 'school') return Colors.purple;
    if (n == 'ogs') return Colors.cyan;
    if (n == 'gaming') return Colors.indigo;
    if (n == 'goat') return Colors.amber;
    if (n == 'doggo') return Colors.brown;
    if (n == 'internet') return Colors.teal;
    if (n == 'bff') return Colors.pink;
    if (n == 'celebrity') return Colors.deepPurple;
    if (n == 'favorite') return Colors.yellow;
    if (n == 'couple') return Colors.deepOrange;
    return Colors.grey;
  }
}

extension BirthdayUpcoming on BirthdayModel {
  /// Next birthday occurrence (today or in the future).
  DateTime get nextOccurrence {
    final DateTime now = DateTime.now();
    final DateTime todayAtMidnight = DateTime(now.year, now.month, now.day);
    DateTime candidate = DateTime(now.year, date.month, date.day);

    // If the birthday already fell strictly before today this year.
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

  /// Current age of the contact (adjusted if the birthday has not happened yet).
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
  List<BirthdayModel> get nextBirthdays {
    if (isEmpty) return [];

    final sorted = List<BirthdayModel>.from(this)
      ..sort((a, b) => a.daysUntilNext.compareTo(b.daysUntilNext));

    final minDays = sorted.first.daysUntilNext;
    return sorted.where((b) => b.daysUntilNext == minDays).toList();
  }
}
