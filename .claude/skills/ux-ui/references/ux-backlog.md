# UX backlog — audit of 2026-10-07

Living list of what to improve, from a full audit with the snapshot tool (light, dark, 200 % text,
360×640) and the palette audit. The current UI is a **draft, not a constraint**: the "big bets"
below deliberately question structure, not just polish.

Evidence: regenerate with the snapshot tool (home, home_empty, birthday_form, calendar, loading,
scanner, settings, auth). Shipped items are gone (git history holds them); device checks still
owed are in architecture `migration.md` §1.

Rules: verify an item still exists before acting (code moves); delete items you fix; add what you
find (one line, evidence, priority). Big bets and anything touching the data model, navigation,
auth or dependencies → design brief + maintainer approval first.

Ids (B, D, F, Q, S) are this backlog's; elsewhere cite them as « ux D17 ». The architecture decisions D1–D12 live in `architecture/references/decisions.md` and are cited « decision D9 ».

## Contents
- Big bets (B4's gift ideas, deferred; B8) — structural redesigns with the highest impact
- P2 — polish (D17, D28, D29)
- Suggested roadmap

---

## Big bets

### B4 — Gift ideas per person (deferred)
- Notes on the person page stay out (a new field).
- **Deferred** (maintainer, 2026-11-03: a good idea, for later, not now): tab 2
  « Scanner » → « Idées », ideas per person + an unassigned inbox, added by text, link or ISBN
  scan (the scanner becomes one input); then the ideas on the person page (B4c: a slot built by
  `ideas`, passed by `app/router`, no edge from `birthday`), « Idée cadeau » on the J-0 hero and
  « 2 idées pour Léa » in the J-7 notification (B4d, needs B8 step 2). Settled in the brief of
  2026-11-01, to reuse when it starts:
  - a new `ideas` feature absorbs `book_scanner` (`git mv` alone first); graph `ideas: {auth,
    birthday}`, `settings` → `ideas`;
  - `Idea` in `user/{uid}/ideas/{id}`: `title`, optional `personId` (absent = the inbox; an id no
    longer in the agenda falls back to it, no cascade write), `url`, `isbn`, `authors`,
    `imageUrl`, `createdAt`; owner-only rules tested in the emulator first; erased by
    `AccountDeletion`; ordered by `createdAt`, no composite index;
  - routes `/ideas` (tab) and `/scan` (pushed: the camera no longer runs in a mounted tab); pure
    `parseIdeaText` (the first http(s) word is the link) and `groupIdeas` (inbox, then people by
    next birthday);
  - `url_launcher` approved (2026-11-03) to open a link; the existing `books` documents: migrate
    them or let them go, to decide then;
  - the scanner's book carousel goes.
- **Refs**: Apple/Google Contacts cards, wishlist apps, Pinterest boards (lightweight).
- **Cost**: medium (ideas model and rules, the tab, scanner integration).

### B8 — The age in reminders (brief 2026-10-25; workmanager approved 2026-11-01)
- Step 1 is in (workmanager, daily background replan on Android, `reminders.md`); step 2 waits
  for the measure on the maintainer's Honor.
- **Left, step 1**:
  - Not proven on a device: a run offline with the app's process dead. The emulator can't show it: earlier clock
    moves left a future « FORCE STOP » exit record, then the job vanished from JobScheduler
    while WorkManager's database still holds it (`reminders.md`, Platform). Proven: job
    registered, kept after a reboot, one completed run (`period_count` 1), alarms replanned
    at every launch.
  - The measure on the Honor (procedure: session notes `b8-mesure-honor.md`, to copy into
    the device skill if it's kept): debug APK through `scripts/build_and_deploy.ps1` (no
    `flutter run`, its tab force-stops the app), default battery settings, a daily reading
    for at least 10 days, with 3 days without opening AnKi, a reboot and a time offline. Read
    `period_count`, `last_enqueue_time` and `run_attempt_count` in
    `no_backup/androidx.work.workdb` (`run-as` + sqlite3), plus the standby bucket, the
    alarm count and force-stops (`dumpsys activity exit-info`). Good: +1 per ~24 h (≤ 36 h
    apart), reboot and offline included → step 2. Delays of a few days: the 45-day window
    absorbs them. Nothing runs → revisit `decisions.md` D12.
- **Next, step 2** (after the measure): one-shots with the age inside a 45-day window,
  the yearly ageless repeat beyond it, on the same ids (`planReminders(…, oneShotUntil:)`,
  `PlannedReminder.repeats`, `ReminderNotification.repeats`); ARB age variants of the two
  bodies (ICU plural, « son premier anniversaire » for 1); `reminders.md` invariants rewritten.
  Contacts imported before 2026-10-12 without a year read as born in 2000, so they get an age
  too; each is fixed in the sheet. Step 3: iOS (BGTaskScheduler identifier in `Info.plist`,
  registration on iOS, with D17).
- **Problem**: reminders say « Demain, Léa fête son anniversaire. », not « Demain, Léa fête ses
  30 ans » — the detail that turns a reminder into a thoughtful wish (patterns §I). A yearly
  repeating notification keeps the text it was scheduled with, so an age would go stale. A
  one-shot with the age + a yearly ageless fallback fails on Android:
  `matchDateTimeComponents` drops the year (`getNextFireDateMatchingDateTimeComponents`,
  flutter_local_notifications 22.3), so the fallback fires the same day as the one-shot.
- **For whom / job**: everyone with known birth years (most of an imported agenda), at the
  « act on it » moment: the notification is often the only screen they see that day.
- **Proposal — rolling window, replanned in the background**: each reminder keeps one stable
  id (B6 ranges). Inside a window (the next 45 days, beyond J-30) it is a **one-shot** with the
  exact age; beyond it, the **yearly ageless repeat** it is today. Every replan (app start, data
  change, and the **daily background task**) turns the reminders entering the window into
  one-shots, on the same id, so nothing is ever scheduled twice. Unknown year → ageless as
  today. The background replan (step 1) initializes Firebase in a callback isolate, reads the
  signed-in user's birthdays and preferences from the Firestore offline cache, and runs the same
  `planReminders` + `NotificationService.scheduleAll`. Reference: calendar apps (Google Agenda,
  Fantastical) roll their alarms over a short window the same way; Facebook-style « Léa a 30 ans
  aujourd'hui » copy.
- **Rejected**: one-shot + yearly fallback (double notification, see above); one-shots only,
  replanned at app start (a phone left unopened past an occurrence loses every later reminder:
  breaks the core promise); the age in a repeating text (stale after a year); a native receiver
  writing the text at fire time from the birth year (replaces the plugin's Android code: against
  « native code stays small », and still nothing on iOS); the age only in the app (already on the
  hero and the agenda, it doesn't reach the notification).
- **Mock-up**:
  ```
  🎉 Léa Martin                      🎂 Léa Martin
  Demain, Léa fête ses 30 ans.       Léa fête ses 30 ans aujourd'hui !   [Souhaiter]
  (year unknown, or beyond the window: today's ageless texts)
  ```
- **Risk check**: the window's one-shot is the only scheduled alarm for that occurrence; if
  neither the app nor the worker runs between its firing and the next window (~320 days), the
  following year is missed. A force-stop already cancels every alarm today, and WorkManager runs
  at least daily on stock Android; aggressive OEMs (Honor, Xiaomi) can delay it: hence the
  measure before step 2, and a wide window (45 days) so a late worker still catches up.
- **Impact of step 2**: domain `planReminders(…, oneShotUntil:)` and `PlannedReminder.repeats`;
  core `ReminderNotification.repeats` (`matchDateTimeComponents` only when true); ARB age
  variants of the two notification bodies; tests per layer; `reminders.md` invariants rewritten
  (an age is allowed in a one-shot only). No Firestore change, no migration. iOS: the same window
  also answers iOS's 64-pending cap.
- **Cost of what's left**: medium (plan and service changes, the measure).

## P2 — polish

- **D17 iOS wish button**: iOS notifications have no « Souhaiter » (Darwin categories are
  declared at initialization, before the texts are localized) → add a category once iOS builds.
- **D28 light flash at cold start** (seen 2026-11-05 on the emulator, dark profile, light
  system): native splash (#121318) → blank light screen → dark home. `_StartupScreen`
  (`app/router/app_router.dart`) is an empty `Scaffold` painted with `ThemeMode.system`, since
  `themeProvider` waits for the profile → paint it in the splash colour, or start from the last
  theme kept on the device. Priority: medium, seen on every cold start.
- **D29 guest details lost on a merge duplicate** (B5.5, 2026-11-05): when a guest's birthday
  matches one already in the Google account, the account's record wins and the guest's photo,
  wished years and own reminders on it are dropped → fill the account record's empty fields from
  the guest's. Priority: low, only if it matters.
- **D30 person page still on the moon disc** (2026-11-08): the home tiles moved S3 to the orbit
  (`OrbitCountdown`), the person page header keeps `MoonPhase` next to « Dans N jours »
  (`person_screen.dart`) → give it the orbit around the days (or the coming age), then delete
  `moon_phase.dart` and its test. Priority: medium, the one place two S3 forms coexist.

## Suggested roadmap

1. **B8, D17, D28, D30** — depth and polish (D29 if it matters);
   natural-language quick add (« Léa 12 mars ») once the typed date proves the bottleneck.
2. **B4's gift ideas** — when the maintainer picks them up.
