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
  yearly through `matchDateTimeComponents: dateAndTime`).
- A repeating notification keeps the text written when it was scheduled: never put an age, or
  anything else that changes yearly, in a notification text (`age` travels with the plan but
  stays out of the texts). A one-shot with the age plus a yearly ageless fallback doesn't work
  with this plugin: on Android, `matchDateTimeComponents` drops the year and fires at the next
  matching date, so the fallback would fire the same day as the one-shot. The age needs a
  background replan (WorkManager, a new plugin): B6 shipped without it.
- Android 12+ refuses more than 500 alarms per app, silently for us: the plan keeps at most
  `ReminderPolicy.maxScheduled` (450), J-0 first, then J-7, J-1, J-30, nearest first.
- `ReminderNotification.daysBefore` picks the text: 0 is the day (« 🎂 Léa Martin », « Léa fête
  son anniversaire aujourd'hui ! », « Souhaiter »), otherwise « 🎉 Léa Martin », « Demain, Léa
  fête son anniversaire. » or « Dans 7 jours, … ».
- `reminderSyncProvider` replans on every new birthdays list and every new setting (sign-out →
  empty list → all cancelled); `app/` keeps it alive by watching it from an always-mounted widget.
- Texts come from the ARB through `NotificationStrings.fromL10n`, injected by `app/`; the French
  set in the service is only the fallback before that.
- The J-0 notification carries « Souhaiter » (`NotificationActions.wish`, Android only); its
  payload is the birthday id, routed by `app/bootstrap/app_initializer.dart`.

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
