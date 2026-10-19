import 'package:an_ki/features/reminders/domain/reminder_plan.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Rendu des rappels : textes affichés, dans la langue de l'app.
extension ReminderDisplay on BuildContext {
  String get _locale => Localizations.localeOf(this).languageCode;

  /// Heure des rappels de la politique : « 10:00 », « 10:00 AM ».
  String get reminderTime =>
      DateFormat.jm(_locale).format(DateTime(2000, 1, 1, ReminderPolicy.hour));

  /// Jour d'un rappel : « mardi 21 octobre ».
  String reminderDay(PlannedReminder reminder) =>
      DateFormat.MMMMEEEEd(_locale).format(reminder.at);

  /// Heure d'un rappel : « 10:00 ».
  String reminderClock(PlannedReminder reminder) =>
      DateFormat.jm(_locale).format(reminder.at);
}
