import 'dart:math' as math;

import 'package:an_ki/features/birthday/domain/birth_date.dart';

/// Ordre du jour et du mois dans une date tapée : celui des dates courtes de
/// la région, « 12/03 » en France, « 03/12 » aux États-Unis.
enum DayMonthOrder {
  dayFirst,
  monthFirst;

  /// Ordre d'un motif de date courte (`DateFormat.yMd` : « dd/MM/y »,
  /// « M/d/y », « y-MM-dd ») : le mois d'abord quand il précède le jour.
  static DayMonthOrder fromPattern(String pattern) {
    final month = pattern.indexOf('M');
    final day = pattern.indexOf('d');
    return month >= 0 && day >= 0 && month < day ? monthFirst : dayFirst;
  }
}

/// Ce que donne une date d'anniversaire tapée au clavier : jour et mois dans
/// l'ordre de la région, puis l'année facultative (« 12/03 » ou
/// « 12/03/1990 »).
sealed class BirthDateInput {
  const BirthDateInput();
}

/// Rien n'est tapé.
final class BirthDateEmpty extends BirthDateInput {
  const BirthDateEmpty();

  @override
  bool operator ==(Object other) => other is BirthDateEmpty;

  @override
  int get hashCode => (BirthDateEmpty).hashCode;
}

/// Saisie en cours : le second nombre, jour ou mois, attend ses chiffres.
final class BirthDateIncomplete extends BirthDateInput {
  const BirthDateIncomplete();

  @override
  bool operator ==(Object other) => other is BirthDateIncomplete;

  @override
  int get hashCode => (BirthDateIncomplete).hashCode;
}

/// Une date d'anniversaire complète, avec ou sans année.
final class BirthDateComplete extends BirthDateInput {
  const BirthDateComplete(this.date);

  final BirthDate date;

  @override
  bool operator ==(Object other) =>
      other is BirthDateComplete && other.date == date;

  @override
  int get hashCode => date.hashCode;
}

/// Une saisie qui ne donne pas de date, et pourquoi.
final class BirthDateInvalid extends BirthDateInput {
  const BirthDateInvalid(this.error);

  final BirthDateError error;

  @override
  bool operator ==(Object other) =>
      other is BirthDateInvalid && other.error == error;

  @override
  int get hashCode => error.hashCode;
}

/// Pourquoi une saisie ne donne pas de date.
enum BirthDateError {
  /// Ce jour n'existe pas : « 31/04 », « 12/13 », « 29/02/1990 ».
  noSuchDate,

  /// L'année n'a pas encore ses quatre chiffres : « 12/03/199 ».
  incompleteYear,

  /// La date est après aujourd'hui.
  future,
}

/// Lit une date d'anniversaire tapée au clavier, jour et mois dans l'[order]
/// de la région, puis l'année facultative ; une date après [today] est
/// refusée.
///
/// Tolère la saisie sans séparateur (« 1203 », « 12031990 »), le jour ou le
/// mois à un chiffre (« 1/3 ») et les séparateurs « / », « . », « - » ou
/// espace. L'année s'écrit avec ses quatre chiffres.
BirthDateInput parseBirthDate(
  String text,
  DateTime today, {
  DayMonthOrder order = DayMonthOrder.dayFirst,
}) {
  final input = text.trim();
  if (input.isEmpty) return const BirthDateEmpty();
  if (!_allowed.hasMatch(input)) {
    return const BirthDateInvalid(BirthDateError.noSuchDate);
  }
  final parts = _digitsOnly.hasMatch(input)
      ? _fixedWidthParts(input)
      : input.split(_separators);
  final first = parts[0];
  final second = parts.length > 1 ? parts[1] : '';
  final yearText = parts.length > 2 ? parts[2] : '';
  if (parts.length > 3 ||
      first.isEmpty ||
      first.length > 2 ||
      second.length > 2 ||
      yearText.length > 4) {
    return const BirthDateInvalid(BirthDateError.noSuchDate);
  }
  // Un second nombre vide ou réduit à « 0 » attend encore ses chiffres.
  if (second.isEmpty || second == '0') return const BirthDateIncomplete();

  final (dayText, monthText) = switch (order) {
    DayMonthOrder.dayFirst => (first, second),
    DayMonthOrder.monthFirst => (second, first),
  };
  final day = int.parse(dayText);
  final month = int.parse(monthText);
  // Sans année, une année bissextile : le 29 février existe.
  if (month < 1 || month > 12 || day < 1 || day > _daysIn(month, 2000)) {
    return const BirthDateInvalid(BirthDateError.noSuchDate);
  }
  if (yearText.isEmpty) {
    return BirthDateComplete(BirthDate(month: month, day: day));
  }
  if (yearText.length < 4) {
    return const BirthDateInvalid(BirthDateError.incompleteYear);
  }
  final year = int.parse(yearText);
  if (day > _daysIn(month, year)) {
    return const BirthDateInvalid(BirthDateError.noSuchDate);
  }
  if (DateTime(year, month, day).isAfter(_dayOf(today))) {
    return const BirthDateInvalid(BirthDateError.future);
  }
  return BirthDateComplete(BirthDate(year: year, month: month, day: day));
}

/// Met en forme la saisie pendant la frappe : chiffres groupés par deux, deux
/// puis quatre (jour, mois et année dans l'ordre de la région), séparés par
/// « / » dès que le groupe suivant commence
/// (« 1203 » → « 12/03 »). Un séparateur tapé clôt le groupe en cours
/// (« 1/ » pour le 1er) ; les autres caractères et les chiffres en trop sont
/// ignorés.
String maskBirthDateInput(String text) {
  const widths = [2, 2, 4];
  final groups = [StringBuffer()];
  for (final char in text.split('')) {
    final group = groups.last;
    final isFull = group.length == widths[groups.length - 1];
    final isLast = groups.length == widths.length;
    if (_digit.hasMatch(char)) {
      if (!isFull) {
        group.write(char);
      } else if (!isLast) {
        groups.add(StringBuffer(char));
      }
    } else if (_separator.hasMatch(char) && group.isNotEmpty && !isLast) {
      groups.add(StringBuffer());
    }
  }
  return groups.join('/');
}

/// Texte du champ pour une date connue, dans l'[order] de la région :
/// « 15/10 » ou « 12/03/1990 » (« 10/15 », « 03/12/1990 » mois d'abord).
String birthDateInputText(
  BirthDate date, {
  DayMonthOrder order = DayMonthOrder.dayFirst,
}) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final (first, second) = switch (order) {
    DayMonthOrder.dayFirst => (date.day, date.month),
    DayMonthOrder.monthFirst => (date.month, date.day),
  };
  final dayMonth = '${twoDigits(first)}/${twoDigits(second)}';
  return switch (date.year) {
    final year? => '$dayMonth/${year.toString().padLeft(4, '0')}',
    null => dayMonth,
  };
}

final _allowed = RegExp(r'^[0-9/.\- ]+$');
final _digitsOnly = RegExp(r'^[0-9]+$');
final _separators = RegExp(r'[/.\- ]+');
final _digit = RegExp(r'[0-9]');
final _separator = RegExp(r'[/.\- ]');

/// « 1203 » → « 12 » et « 03 » ; la suite est l'année.
List<String> _fixedWidthParts(String digits) => [
  digits.substring(0, math.min(2, digits.length)),
  if (digits.length > 2) digits.substring(2, math.min(4, digits.length)),
  if (digits.length > 4) digits.substring(4),
];

/// Nombre de jours de [month] l'année [year].
int _daysIn(int month, int year) => DateTime(year, month + 1, 0).day;

DateTime _dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
