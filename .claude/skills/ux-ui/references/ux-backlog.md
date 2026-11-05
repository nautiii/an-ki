# UX backlog — audit of 2026-10-07

Living list of what to improve, from a full audit with the snapshot tool (light, dark, 200 % text,
360×640) and the palette audit. The current UI is a **draft, not a constraint**: the "big bets"
below deliberately question structure, not just polish.

Evidence: regenerate with the snapshot tool (home, home_empty, birthday_form, calendar, loading,
scanner, settings, auth). Roadmap steps 1 (F2, F3, A1–A8), 2 (B1, Q1, Q2, A9) and 3 (B2)
shipped on 2026-10-12, step 4 (B3, D7) and steps 5.1–5.2 (B5 welcome and contacts import, Q5)
on 2026-10-18, steps 5.3 (B5 reminders in context, D19 for the J-0 notification) and 5.4 (B5
guest backup) on 2026-10-19, small fixes D6, D19, D20 and D21, Q6 and D18, the e-mail sign-in
and sign-up forms (D3, their part of F5, D11 and D1, their copy), the settings (Q4, F4, the
rest of D1, their part of F5 and D11), the groups (B7, Q7, the rest of D11) and the
reminders-off card (Q8), the forgotten password link (Q9) and the auth messages (D23) on
2026-10-24, then the sign-up's single password (Q11), D24, D9, D22, D12, D14 (its message),
D8, F5 and D4, and the groups page (Q10) on 2026-10-25, then D25 and D15 (the belated wish) on
2026-10-27, then D27 (« e-mail » with a plain hyphen, U+00A0 for the narrow U+202F Outfit
lacks) on 2026-11-02, then B4a (the person page, with D14's « Voir ») on 2026-11-03, then D10
(the scanner tab's pinned app bar, its carousel at its own height) on 2026-11-05: the items
they fixed are gone from this list.

Rules: verify an item still exists before acting (code moves); delete items you fix; add what you
find (one line, evidence, priority). Big bets and anything touching the data model, navigation,
auth or dependencies → design brief + maintainer approval first.

## Contents
- Big bets (B4's gift ideas, deferred; B8; B5 and B6 shipped but their merge) — structural redesigns with the highest impact
- Foundation (none open) — design system, prerequisite for consistency
- P2 — polish (D17)
- Suggested roadmap

---

## Big bets

### B4 — Person page (view-first) + gift ideas per person
- **Shipped, B4a person page** (2026-11-03, branch `claude/b4-brief-4e460b`): a tap on a person
  (agenda row, hero, « Hier » card, calendar day sheet, a reminder notification) opens
  `/person/:id`, not the edit sheet: large avatar ringed by its groups, moon countdown, birth
  date, age, group chips, « Souhaiter » on the day and the day after, the person's reminders
  (moved out of the edit sheet, written at once), the wish history (`wishedYears`) whose current
  year can be undone; « Modifier » opens the edit sheet. The add confirmation (D14) gains
  « Voir », which opens the new page. Notes stay out (a new field).
- **Deferred — gift ideas** (maintainer, 2026-11-03: a good idea, for later, not now): tab 2
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
  - the scanner's book carousel goes (debt A15 was fixed on 2026-11-03; its pinned app bar
    shipped with D10 on 2026-11-05).
- **Refs**: Apple/Google Contacts cards, wishlist apps, Pinterest boards (lightweight).
- **Cost of what's left**: medium (ideas model and rules, the tab, scanner integration).

### B5 — Value-first onboarding (approved 2026-10-18, candidate B « directement chez soi »)
- **Shipped, 5.3** (2026-10-19): no permission request at launch; `ReminderOfferSheet` after an
  import, the first birthdays added by hand or a sign-in that brings an agenda (« 12
  anniversaires ajoutés / retrouvés », the cadence, the next real J-0 reminder); at most once per
  session; Settings › Rappels (`RemindersTile`); blocked → « Ouvrir les réglages ». Details:
  patterns §H, `.claude/rules/reminders.md`.
- **Shipped, 5.4** (2026-10-19): from 3 birthdays a guest finds `GuestBackupCard` after the
  agenda's last month, never in the calendar (« Gardez vos 12 anniversaires » · « Sauvegarder
  avec Google »); linked, the card goes, « Vos 12 anniversaires sont sauvegardés », and the
  profile takes the Google names. A Google account AnKi already knows
  (`credential-already-in-use`, or its address on an e-mail account) changes nothing: the card
  explains it and offers « Choisir un autre compte ». Details: patterns §H. Not seen on a device
  yet (architecture `migration.md` §1).
- **Later — 5.5 merge** (option B, set aside on 2026-10-19): « Ouvrir ce compte avec mes 12
  anniversaires » signs in to the existing account, then copies the guest's birthdays without
  duplicates (the import's matching rule). A copy between accounts leaves the guest's documents
  orphaned in Firestore, out of the app's reach → system change, brief and approval first.
- Prototypes in `build/ui_snapshots/_src/` (local only — `flutter clean` wipes `build/`):
  `etape5_test.dart` (the flow, Q8's card), `etape54_test.dart` (each state of the shipped card).
- **Refs**: Duolingo lazy sign-up, Google Keep/Todoist empty-state onboarding, Instagram priming.

### B6 — Reminders you control (approved 2026-10-25)
- **Shipped** (2026-10-25, branch `claude/peaceful-noether-e0fb53`): Settings › Anniversaires
  gains « Me prévenir » (J-30, J-7, J-1 chips; J-0 always) and « Heure des rappels » (system time
  picker), stored in `user/{uid}.reminders`; the « Rappels » row sums it up (« 7 jours avant ·
  Le jour J · 10:00 ») and the offer sheet follows it. The birthday sheet gains « Rappels »:
  Comme d'habitude / Aucun / Personnalisés (`birthday/{id}.reminders`), moved to the person
  page with B4a (2026-11-03). Notifications before the day are personal: « 🎉 Léa Martin », « Demain, Léa fête
  son anniversaire. ». The plan stays under Android's 500-alarm limit, J-0 first.
- **Dropped**: quiet hours (one chosen time makes them redundant); the Monday digest (maintainer,
  2026-10-25).
- **Left**: the age in the text (« Léa fête ses 30 ans ») → B8.

### B8 — The age in reminders (brief 2026-10-25; workmanager approved 2026-11-01)
- **Shipped, step 1** (2026-11-01): workmanager 0.10.10, a daily background replan on Android,
  texts unchanged (`reminders.md`). Step 2 waits for the measure on the maintainer's Honor
  (does the job run every day?).
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
  D13 was dropped (2026-11-01): contacts imported before 2026-10-12 without a year read as born
  in 2000, so they get an age too; each is fixed in the sheet. Step 3: iOS (BGTaskScheduler identifier in `Info.plist`, registration on iOS, with D17).
- **Problem**: reminders say « Demain, Léa fête son anniversaire. », not « Demain, Léa fête ses
  30 ans » — the detail that turns a reminder into a thoughtful wish (patterns §I). A yearly
  repeating notification keeps the text it was scheduled with, so an age would go stale. The
  B6 idea (one-shot with the age + yearly ageless fallback) fails on Android:
  `matchDateTimeComponents` drops the year (`getNextFireDateMatchingDateTimeComponents`,
  flutter_local_notifications 22.3), so the fallback fires the same day as the one-shot.
- **For whom / job**: everyone with known birth years (most of an imported agenda), at the
  « act on it » moment: the notification is often the only screen they see that day.
- **Proposal — rolling window, replanned in the background**: each reminder keeps one stable
  id (B6 ranges). Inside a window (the next 45 days, beyond J-30) it is a **one-shot** with the
  exact age; beyond it, the **yearly ageless repeat** it is today. Every replan (app start, data
  change, and now a **daily background task**) turns the reminders entering the window into
  one-shots, on the same id, so nothing is ever scheduled twice. Unknown year → ageless as
  today. Background replan with **workmanager** (Android WorkManager / iOS BGTaskScheduler,
  periodic ~24 h, no network needed): a callback isolate initializes Firebase, reads the
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
  at least daily on stock Android; aggressive OEMs (Honor, Xiaomi) can delay it: measure on the
  maintainer's phone before step 2, and keep the window wide (45 days) so a late worker still
  catches up.
- **Impact**: `pubspec.yaml` + `workmanager` pinned (new plugin: approval; androidx.work merges
  `RECEIVE_BOOT_COMPLETED` into the manifest, already granted to flutter_local_notifications);
  `main.dart` registers the callback dispatcher; a background entry in `app/bootstrap` (Firebase
  init, timezone, notification strings from the profile locale through
  `lookupAppLocalizations`, no `BuildContext`); domain: `planReminders(…, oneShotUntil:)` and
  `PlannedReminder.repeats`; core: `ReminderNotification.repeats` (`matchDateTimeComponents`
  only when true); ARB: age variants of the two notification bodies (ICU plural on `age`, « son
  premier anniversaire » for 1); tests per layer; `reminders.md` invariants rewritten (an age is
  allowed in a one-shot only). No Firestore change, no migration. iOS: BGTaskScheduler identifier
  in `Info.plist` once iOS builds; the same window also answers iOS's 64-pending cap.
- **Steps**: 1) workmanager + daily background replan, texts unchanged — prove on the phone that
  it runs (`adb shell dumpsys jobscheduler`), offline and after a reboot; 2) one-shots with the
  age inside the window; 3) iOS rolling window, when iOS builds (with D17).
- **Cost**: medium (one plugin, a background isolate, plan and service changes).

## Foundation

None open: F1 (bundled Outfit) and F6 (error ring on fields) shipped 2026-10-26.

## P2 — polish

- **D17 iOS wish button**: iOS notifications have no « Souhaiter » (Darwin categories are
  declared at initialization, before the texts are localized) → add a category once iOS builds.

## Suggested roadmap

1. **B5's 5.5 merge** once guests with an existing Google account show up.
2. **B8, D17** — depth and polish;
   natural-language quick add (« Léa 12 mars ») once the typed date proves the bottleneck.
3. **B4's gift ideas** — when the maintainer picks them up.
