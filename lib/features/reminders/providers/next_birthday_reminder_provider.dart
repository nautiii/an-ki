import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/reminders/domain/reminder_plan.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:an_ki/features/reminders/providers/reminder_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Prochain rappel du jour J que l'app enverra ([nextBirthdayReminder]) :
/// l'exemple réel de la proposition des rappels. Null sans anniversaire
/// rappelé.
final nextBirthdayReminderProvider = Provider.autoDispose<PlannedReminder?>((
  ref,
) {
  final birthdays = ref.watch(birthdaysListProvider);
  final preferences =
      ref.watch(effectiveReminderPreferencesProvider) ??
      const ReminderPreferences();
  // Recalculé chaque jour : le rappel d'hier n'est plus le prochain.
  ref.watch(todayProvider);
  return nextBirthdayReminder(
    birthdays,
    now: ref.watch(clockProvider)(),
    preferences: preferences,
  );
});
