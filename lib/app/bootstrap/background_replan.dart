import 'dart:async';

import 'package:an_ki/app/bootstrap/notification_strings.dart';
import 'package:an_ki/core/firebase_options.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:an_ki/features/reminders/providers/reminder_preferences_provider.dart';
import 'package:an_ki/features/reminders/providers/reminder_sync_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

/// Nom unique de la replanification quotidienne auprès de WorkManager.
const String backgroundReplanTask = 'reminders-replan';

/// Enregistre la replanification des rappels en tâche de fond, environ
/// toutes les 24 h, sans condition de réseau : un téléphone resté sans
/// ouvrir l'app garde des rappels à jour (B8).
///
/// Android seulement : iOS demande d'abord un identifiant BGTaskScheduler
/// dans `Info.plist` (B8, étape 3). Un échec n'empêche pas l'app de
/// démarrer : elle replanifie à chaque lancement de toute façon.
Future<void> registerBackgroundReplan([
  @visibleForTesting Workmanager? workmanager,
]) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final tasks = workmanager ?? Workmanager();
  try {
    await tasks.initialize(backgroundReplanDispatcher);
    // keep : chaque lancement de l'app ne repousse pas la prochaine exécution.
    await tasks.registerPeriodicTask(
      backgroundReplanTask,
      backgroundReplanTask,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } catch (error) {
    debugPrint('[BackgroundReplan] registration failed: $error');
  }
}

/// Point d'entrée de la tâche de fond, dans un isolate sans l'app : Firebase
/// et les notifications (zones horaires comprises) y sont initialisés à
/// nouveau. Un échec rend la main à WorkManager, qui réessaie plus tard.
@pragma('vm:entry-point')
void backgroundReplanDispatcher() {
  Workmanager().executeTask((task, _) async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await NotificationService.instance.initialize();
      // Sans nouvel essai de Riverpod : WorkManager s'en charge.
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [localizedNotificationStrings],
      );
      try {
        await replanInBackground(container);
      } finally {
        container.dispose();
      }
      return true;
    } catch (error) {
      debugPrint('[BackgroundReplan] failed: $error');
      return false;
    }
  });
}

/// Replanifie les rappels de l'utilisateur connecté, lus dans le cache hors
/// ligne de Firestore, par le même chemin que l'app ([scheduleReminders]),
/// avec les textes de la langue du profil.
///
/// Sans session ou sans anniversaire, ne touche à rien : l'app annule
/// elle-même les rappels à la déconnexion et à la dernière suppression, et
/// une liste vide lue ici pourrait venir d'un cache vidé.
Future<void> replanInBackground(ProviderContainer container) async {
  // Riverpod met en pause un provider que personne n'écoute : ses flux
  // n'émettraient jamais.
  container
    ..listen(authUserProvider, (_, _) {})
    ..listen(birthdaysProvider, (_, _) {})
    ..listen(reminderPreferencesProvider, (_, _) {})
    ..listen(userProfileProvider, (_, _) {});
  final user = await container.read(authUserProvider.future);
  if (user == null) return;
  final birthdays = await container.read(birthdaysProvider.future);
  if (birthdays.isEmpty) return;
  // Réglage illisible : celui d'avant B6, comme dans l'app.
  final preferences = await container
      .read(reminderPreferencesProvider.future)
      .onError((_, _) => const ReminderPreferences());
  // Profil illisible : la langue du téléphone, comme sans choix enregistré.
  await container.read(userProfileProvider.future).onError((_, _) => null);
  // Textes dans la langue de l'app ([localizedNotificationStrings]).
  final strings = container.read(notificationStringsProvider);

  final notifications = container.read(notificationServiceProvider);
  await scheduleReminders(
    notifications,
    birthdays,
    now: container.read(clockProvider)(),
    preferences: preferences,
    strings: strings,
  );

  // L'app ouverte a pu changer la liste ou le réglage pendant la
  // planification (même cache Firestore, mêmes alarmes) : sa replanification
  // a pu être effacée par celle-ci, on replanifie avec la dernière version.
  // Vidée pendant cette exécution, la liste est une vraie suppression (ou une
  // déconnexion) : tout est annulé, comme dans l'app.
  // shortcut: une seule reprise, assez pour un changement fait pendant les
  // quelques secondes de planification.
  final latest = container.read(birthdaysProvider).value ?? birthdays;
  final latestPreferences =
      container.read(reminderPreferencesProvider).value ?? preferences;
  if (listEquals(latest, birthdays) && latestPreferences == preferences) {
    return;
  }
  await scheduleReminders(
    notifications,
    latest,
    now: container.read(clockProvider)(),
    preferences: latestPreferences,
    strings: strings,
  );
}
