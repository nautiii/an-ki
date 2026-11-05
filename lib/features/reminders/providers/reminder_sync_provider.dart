import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/reminders/domain/reminder_plan.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:an_ki/features/reminders/providers/reminder_preferences_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Garde les notifications locales alignées sur les anniversaires de
/// l'utilisateur courant, sur son réglage et sur la langue de l'app : chaque
/// nouvelle liste, chaque réglage ou langue modifiés est replanifié
/// ([planReminders]) puis confié au service. Hors session, la liste est vide
/// et les rappels sont annulés.
///
/// Rien n'est touché tant que Firebase restaure la session : la liste vide de
/// ce moment-là n'est pas une déconnexion et annulerait tous les rappels. Le
/// réglage est attendu de même ; illisible, celui d'avant B6 s'applique
/// plutôt que de ne plus rien planifier.
///
/// Activé par `app/`, qui le `watch` depuis un widget toujours monté : Riverpod
/// met en pause un provider que personne n'écoute.
final reminderSyncProvider = Provider<void>((ref) {
  final sessionKnown = ref.watch(
    authUserProvider.select((user) => user.hasValue || user.hasError),
  );
  if (!sessionKnown) return;
  final preferences = ref.watch(effectiveReminderPreferencesProvider);
  final notifications = ref.watch(notificationServiceProvider);
  final strings = ref.watch(notificationStringsProvider);
  final clock = ref.watch(clockProvider);
  // Les anniversaires restent écoutés pendant que le réglage se charge : son
  // arrivée reconstruit ce provider, qui planifie la liste déjà là.
  ref.listen(birthdaysProvider, fireImmediately: true, (_, next) {
    if (preferences == null) return;
    if (next case AsyncData(:final value)) {
      unawaited(
        scheduleReminders(
          notifications,
          value,
          now: clock(),
          preferences: preferences,
          strings: strings,
        ).catchError((Object error) {
          // Plugin indisponible : la prochaine liste ou la tâche de fond
          // replanifie.
          debugPrint('[ReminderSync] scheduling failed: $error');
        }),
      );
    }
  });
});

/// Planifie les rappels de [birthdays] ([planReminders]) et les confie à
/// [notifications], rédigés avec [strings] : le même chemin dans l'app et
/// dans la tâche de fond quotidienne (`app/bootstrap/background_replan.dart`).
Future<void> scheduleReminders(
  NotificationService notifications,
  List<Birthday> birthdays, {
  required DateTime now,
  required ReminderPreferences preferences,
  required NotificationStrings strings,
}) {
  final plan = planReminders(birthdays, now: now, preferences: preferences);
  return notifications.scheduleAll([
    for (final reminder in plan) reminder.toNotification(),
  ], strings: strings);
}

extension on PlannedReminder {
  /// Rappel tel que l'attend le service de notifications de `core`.
  ReminderNotification toNotification() => ReminderNotification(
    id: id,
    daysBefore: lead.days,
    name: name,
    fullName: fullName,
    age: age,
    at: at,
    payload: birthdayId,
  );
}
