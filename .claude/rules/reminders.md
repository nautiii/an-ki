---
paths:
  - "lib/features/reminders/**"
  - "lib/core/services/notification_service.dart"
  - "test/features/reminders/**"
  - "test/core/services/notification_service_test.dart"
---

# Reminders — the app's core promise

A missed reminder breaks the one promise AnKi makes: treat every change here as risky.

## Invariants

- The policy is domain code: `ReminderPolicy` in `features/reminders/domain/reminder_plan.dart`
  (J-0 and J-7, 10:00 local time). `planReminders(birthdays, now:)` is pure and takes `now`.
  Custom cadences (backlog B6) change the policy there, never in the service.
- Reminder days are counted in calendar days (`DateTime(y, m, d - 7, hour)`), never with a
  `Duration`, or a reminder spanning a DST change slips by a day; a slot already past this year
  moves to next year. Born on 29 February → 1 March in non-leap years (`birthday_dates.dart`).
- Notification ids are unique within the plan and stable across replans: a birthday keeps its
  natural slot (`hashCode % 100000`, J-7 = slot + 500000) unless it collides, then probes for the
  next free slot. Two reminders on one id erase each other without any error. Keep the slot
  formula, so ids stay the same across app updates.
- `NotificationService` only schedules what it's given: it cancels the pending ids missing from
  the new plan, then schedules each reminder (`zonedSchedule`, `exactAllowWhileIdle`, repeating
  yearly through `matchDateTimeComponents: dateAndTime`).
- A repeating notification keeps the text written when it was scheduled: never put an age, or
  anything else that changes yearly, in a notification text (`age` travels with the plan but
  stays out of the texts).
- `reminderSyncProvider` replans on every new birthdays list (sign-out → empty list → all
  cancelled); `app/` keeps it alive by watching it from an always-mounted widget.
- Texts come from the ARB through `NotificationStrings.fromL10n`, injected by `app/`; the French
  set in the service is only the fallback before that.
- The J-0 notification carries « Souhaiter » (`NotificationActions.wish`, Android only); its
  payload is the birthday id, routed by `app/bootstrap/app_initializer.dart`.

## Platform

- Android 13+ asks for `POST_NOTIFICATIONS`. Exact alarms come from `USE_EXACT_ALARM`, granted at
  install, so `requestExactAlarmsPermission` returns at once. Google Play restricts
  `USE_EXACT_ALARM` to alarm-clock and calendar apps: if it has to go before publishing, Android
  14+ doesn't pre-grant `SCHEDULE_EXACT_ALARM` and the request opens the system settings.
- flutter_local_notifications' boot and update receivers reschedule after a reboot or an app
  update: keep them in the manifest.
- iOS caps pending local notifications at 64, two per birthday: iOS isn't built yet, but it would
  need a rolling window.

## Verify

Unit tests: `reminder_plan_test.dart` (dates, DST, ids, collisions) and
`notification_service_test.dart` (plugin double). Then on the emulator (device skill,
`references/recipes.md` §6): move the clock, read the alarms back, see the notification posted.
