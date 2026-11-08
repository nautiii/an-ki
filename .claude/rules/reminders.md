---
paths:
  - "lib/features/reminders/**"
  - "lib/core/services/notification_service.dart"
  - "lib/app/bootstrap/reminder_prompt.dart"
  - "android/app/src/main/kotlin/**/MainActivity.kt"
  - "test/features/reminders/**"
  - "test/core/services/notification_service_test.dart"
  - "test/app/bootstrap/reminder_prompt_test.dart"
---

# Reminders — the app's core promise

A missed reminder breaks the one promise AnKi makes: treat every change here as risky.

## Invariants

- The policy is domain code (`features/reminders/domain/`), never in the service.
  `ReminderPreferences` is the default setting (B6, Settings › Anniversaires): leads among J-30,
  J-7, J-1 (`ReminderLead`, in `birthday/domain`) plus J-0 always, and one time of day; without
  a stored setting, J-7 + J-0 at 10:00. A birthday may carry its own (`Birthday.reminders`: null
  follows the default, empty mutes it, else its leads plus J-0) — `leadsFor` decides.
  `planReminders(birthdays, now:, preferences:)` is pure and takes `now`.
- Stored in Firestore: the default in `user/{uid}.reminders` (`{leads, hour, minute}`), read and
  written by `ReminderPreferencesRepository` only (the rest of the profile is `user`'s), always
  with `update` so it never creates a profile; a person's own in `birthday/{id}.reminders` (lead
  names; erased with `FieldValue.delete()` when back to the default). Both read tolerantly: an
  unknown lead is skipped, the day itself always added back.
- `effectiveReminderPreferencesProvider` is what applies: the stored setting, or the J-7 + J-0
  10:00 default when it can't be read (better reminders than none); null while it loads, when
  `reminderSyncProvider` keeps listening to the birthdays but plans nothing.
- Reminder days are counted in calendar days (`DateTime(y, m, d - 7, hour)`), never with a
  `Duration`, or a reminder spanning a DST change slips by a day; a slot already past this year
  moves to next year. Born on 29 February → 1 March in non-leap years (`birthday_dates.dart`).
- Notification ids are unique within the plan and stable across replans: a birthday keeps its
  natural slot (`hashCode % 100000`; J-0 = slot, J-1 = slot + 100000, J-30 = slot + 200000,
  J-7 = slot + 500000) unless it collides, then probes for the next free slot. Two reminders on
  one id erase each other without any error. Keep the slot formula, so ids stay the same across
  app updates.
- `NotificationService` only schedules what it's given: it cancels the pending ids missing from
  the new plan, then schedules each reminder (`zonedSchedule`, `exactAllowWhileIdle`, repeating
  yearly through `matchDateTimeComponents: dateAndTime`). `scheduleAll` calls run one after the
  other (overlapping, the older one re-schedules what the newer cancelled), re-read the phone's
  time zone first (travel) and skip a plan identical to the last one (same reminders, texts and
  zone): the Android plugin rewrites its whole stored list on every `zonedSchedule`, so a full
  replan costs O(n²) and every Firestore emission (a wish tap) triggers one. That memory lives
  per isolate and holds only a fully scheduled plan; it doesn't see what the background task
  writes.
- A repeating notification keeps the text written when it was scheduled: never put an age, or
  anything else that changes yearly, in a notification text (`age` travels with the plan but
  stays out of the texts). A one-shot with the age plus a yearly ageless fallback doesn't work
  with this plugin: on Android, `matchDateTimeComponents` drops the year and fires at the next
  matching date, so the fallback would fire the same day as the one-shot. The age needs the
  background replan (below) plus one-shots inside a window: B8 step 2, not done yet.
- Android 12+ refuses more than 500 alarms per app, silently for us: the plan keeps at most
  `ReminderPolicy.maxScheduled` (450), J-0 first, then J-7, J-1, J-30, nearest first.
- `ReminderNotification.daysBefore` picks the text: 0 is the day (« 🎂 Léa Martin », « Léa fête
  son anniversaire aujourd'hui ! », « Souhaiter »), otherwise « 🎉 Léa Martin », « Demain, Léa
  fête son anniversaire. » or « Dans 7 jours, … ».
- `reminderSyncProvider` replans on every new birthdays list, setting and language (sign-out →
  empty list → all cancelled); `app/` keeps it alive by watching it from an always-mounted widget.
  Everything a notification depends on is an input it watches: never push a value into the
  service on the side (a former `configure()` left reminders in the old language).
- A daily background task replans too (B8 step 1, `app/bootstrap/background_replan.dart`):
  `main.dart` registers it with workmanager (Android only for now; periodic 24 h, no network
  constraint, `ExistingPeriodicWorkPolicy.keep`). Its isolate initializes Firebase and
  `NotificationService`, reads the signed-in user's birthdays, setting and the app language
  from the Firestore offline cache and calls the same `scheduleReminders` as
  `reminderSyncProvider`. Signed out or an empty list → it touches nothing (an empty list may
  be an emptied cache; the app cancels on sign-out itself). The app may run at the same time
  (same process, cache and alarms): if the list or setting changed while it scheduled, the task
  replans once more with the latest. A failure returns false and WorkManager retries.
  Why workmanager: architecture `decisions.md` D12.
- Texts come from the ARB through `NotificationStrings.fromL10n`: `notificationStringsProvider`
  (core, throws unless overridden) is overridden by `app/bootstrap/notification_strings.dart`
  (`localizedNotificationStrings`, in the app language: `appLocaleProvider`, the profile choice, else the phone's preferred languages from `deviceLocalesProvider`, else English) in `main()`, in the background
  task's container and in `pumpApp`; each `scheduleAll` receives them. `ReminderNotification`
  carries `name` and `fullName` (`Birthday.fullName`).
- The J-0 notification carries « Souhaiter » (`NotificationActions.wish`, Android only); its
  payload is the birthday id, routed by `app/bootstrap/app_initializer.dart` (a tap on any
  reminder opens that person's page). A person's own reminders are set on their page, written
  alone by `BirthdayRepository.updateReminders`; the edit sheet never touches them.

## Permission — asked in context, never at launch

- Reminders are scheduled whatever the permission: they show once it's granted. Nothing asks at
  launch. `ReminderPrompt` (`app/bootstrap`) offers `ReminderOfferSheet` after an import, the
  first birthdays added by hand (`BirthdaysAdded` from `birthdayAdditionsProvider`), or a sign-in
  made in this run (`freshSignInProvider`) that brings a filled agenda; at most once per
  session, never when granted. Settings › Rappels (`RemindersTile`) is the way back, and the
  home says reminders are off with a calm card (`RemindersOffCard`, from
  `remindersOffNoticeProvider`) that its cross hides for good on this phone.
- The tile, the offer sheet and the card share `ReminderAccessActions`: the system box while it
  can still show, else the app's settings, re-read on resume.
- `ReminderPermission` (`reminderPermissionProvider`) holds `NotificationAccess`: `granted`,
  `denied` (the system box can still show) or `blocked` (only the app's settings can grant).
  Reading (`access`) can't see a block: only a request reveals it, and `refresh` keeps it.
  Screens refresh it on resume (`AppLifecycleListener`), back from the settings.
- `NotificationService.requestAccess`: Android asks `POST_NOTIFICATIONS` (13+), then exact
  alarms; after a refusal it asks `MainActivity` through the `an_ki/notification_permission`
  channel (`canAskAgain` = `shouldShowRequestPermissionRationale`, which the plugin doesn't
  expose): false → blocked (second refusal, or Android 12 and below, where notifications are
  only switched off in the settings). iOS asks once: a refusal is blocked. `openSettings` opens
  the app's notification settings.

## Platform

- Exact alarms come from `USE_EXACT_ALARM`, granted at install, so
  `requestExactAlarmsPermission` returns at once. Google Play restricts `USE_EXACT_ALARM` to
  alarm-clock and calendar apps: if it has to go before publishing, Android 14+ doesn't pre-grant
  `SCHEDULE_EXACT_ALARM` and the request opens the system settings.
- flutter_local_notifications' boot and update receivers reschedule after a reboot or an app
  update: keep them in the manifest.
- workmanager merges `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `ACCESS_NETWORK_STATE`,
  `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_SHORT_SERVICE` (no Play declaration needed);
  WorkManager reschedules its job after a reboot itself. Check it with
  `adb shell dumpsys jobscheduler | grep -A5 an_ki`, force a run with
  `adb shell cmd jobscheduler run -f -n androidx.work.systemjobscheduler <pkg> <job id>`
  (the id changes at every reschedule); its database is `no_backup/androidx.work.workdb`
  (`period_count` = completed runs). A force-stop (closing the `flutter run` tab does one)
  cancels the job and the alarms until the next launch. An emulator whose clock was moved
  forward keeps a « FORCE STOP » exit record dated in the future (`dumpsys activity
  exit-info`): WorkManager then believes in a fresh force-stop at every start and stops each
  forced run (`ForceStopRunnable … rescheduling`), seen 2026-11-02.
- iOS caps pending local notifications at 64, two to four per birthday: iOS isn't built yet, but
  it would need a rolling window.

## Verify

Unit tests: `reminder_plan_test.dart` (dates, DST, ids, collisions, preferences, own setting,
alarm limit), `reminder_preferences_repository_test.dart` (old and unreadable shapes) and
`notification_service_test.dart` (plugin double, mocked permission channel). Then on the
emulator (device skill, `references/recipes.md` §6): move the clock, read the alarms back, see
the notification posted. The permission: `perm reset notifications` for a first ask; a block is
`pm revoke` then `pm set-permission-flags <pkg> android.permission.POST_NOTIFICATIONS
user-set user-fixed`.
