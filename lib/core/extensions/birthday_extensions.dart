import 'package:an_ki/data/models/birthday_model.dart';

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

  Map<String, List<BirthdayModel>> toSections() {
    final Map<String, List<BirthdayModel>> sections = {};

    for (final birthday in this) {
      final String key = birthday.category.name.toUpperCase();

      sections.putIfAbsent(key, () => []);
      sections[key]!.add(birthday);
    }

    return sections;
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
