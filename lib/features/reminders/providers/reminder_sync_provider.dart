import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/reminders/domain/reminder_plan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Garde les notifications locales alignées sur les anniversaires de
/// l'utilisateur courant : chaque nouvelle liste est replanifiée
/// ([planReminders]) puis confiée au service. Hors session, la liste est vide
/// et les rappels sont annulés.
///
/// Rien n'est touché tant que Firebase restaure la session : la liste vide de
/// ce moment-là n'est pas une déconnexion et annulerait tous les rappels.
///
/// Activé par `app/`, qui le `watch` depuis un widget toujours monté : Riverpod
/// met en pause un provider que personne n'écoute.
final reminderSyncProvider = Provider<void>((ref) {
  final sessionKnown = ref.watch(
    authUserProvider.select((user) => user.hasValue || user.hasError),
  );
  if (!sessionKnown) return;
  final notifications = ref.watch(notificationServiceProvider);
  final clock = ref.watch(clockProvider);
  ref.listen(birthdaysProvider, fireImmediately: true, (_, next) {
    if (next case AsyncData(:final value)) {
      final plan = planReminders(value, now: clock());
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
    type: switch (kind) {
      ReminderKind.birthday => ReminderType.birthday,
      ReminderKind.weekBefore => ReminderType.weekBefore,
    },
    name: name,
    surname: surname,
    age: age,
    at: at,
    payload: birthdayId,
  );
}
