import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/reminders/domain/reminder_plan.dart';
import 'package:an_ki/features/reminders/providers/reminder_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Garde les notifications locales alignées sur les anniversaires de
/// l'utilisateur courant et sur son réglage : chaque nouvelle liste, chaque
/// réglage modifié est replanifié ([planReminders]) puis confié au service.
/// Hors session, la liste est vide et les rappels sont annulés.
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
  final clock = ref.watch(clockProvider);
  // Les anniversaires restent écoutés pendant que le réglage se charge : son
  // arrivée reconstruit ce provider, qui planifie la liste déjà là.
  ref.listen(birthdaysProvider, fireImmediately: true, (_, next) {
    if (preferences == null) return;
    if (next case AsyncData(:final value)) {
      final plan = planReminders(value, now: clock(), preferences: preferences);
      unawaited(
        notifications.scheduleAll([
          for (final reminder in plan) reminder.toNotification(),
        ]),
      );
    }
  });
});

extension on PlannedReminder {
  /// Rappel tel que l'attend le service de notifications de `core`.
  ReminderNotification toNotification() => ReminderNotification(
    id: id,
    daysBefore: lead.days,
    name: name,
    surname: surname,
    age: age,
    at: at,
    payload: birthdayId,
  );
}
