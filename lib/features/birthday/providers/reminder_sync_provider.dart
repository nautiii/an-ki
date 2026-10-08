import 'dart:async';

import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Garde les notifications locales alignées sur les anniversaires de
/// l'utilisateur courant : chaque nouvelle liste les replanifie. Hors session,
/// la liste est vide et les rappels sont annulés.
///
/// Activé par `app/`, qui le `watch` depuis un widget toujours monté : Riverpod
/// met en pause un provider que personne n'écoute.
final reminderSyncProvider = Provider<void>((ref) {
  final notifications = ref.watch(notificationServiceProvider);
  ref.listen(birthdaysProvider, fireImmediately: true, (_, next) {
    if (next case AsyncData(:final value)) {
      unawaited(
        notifications.scheduleAll([
          for (final birthday in value)
            BirthdayReminder(
              id: birthday.id,
              name: birthday.name,
              surname: birthday.surname,
              birthDate: birthday.date,
            ),
        ]),
      );
    }
  });
});
