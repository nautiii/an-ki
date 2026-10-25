import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/birthday/widgets/reminder_lead_display.dart';
import 'package:an_ki/features/reminders/domain/reminder_plan.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Rendu des rappels : textes affichés, dans la langue de l'app.
extension ReminderDisplay on BuildContext {
  String get _locale => Localizations.localeOf(this).languageCode;

  /// Heure des rappels d'un réglage : « 10:00 », « 10:00 AM ».
  String reminderTime(ReminderPreferences preferences) =>
      DateFormat.jm(_locale)
          .format(DateTime(2000, 1, 1, preferences.hour, preferences.minute));

  /// Résumé d'un réglage : « 7 jours avant · Le jour J · 10:00 ».
  String reminderSchedule(ReminderPreferences preferences) =>
      l10n.remindersSchedule(
        [
          for (final lead in ReminderLead.values)
            if (lead == ReminderLead.sameDay ||
                preferences.leads.contains(lead))
              reminderLead(lead),
        ].join(' · '),
        reminderTime(preferences),
      );

  /// Jour d'un rappel : « mardi 21 octobre ».
  String reminderDay(PlannedReminder reminder) =>
      DateFormat.MMMMEEEEd(_locale).format(reminder.at);

  /// Heure d'un rappel : « 10:00 ».
  String reminderClock(PlannedReminder reminder) =>
      DateFormat.jm(_locale).format(reminder.at);
}
