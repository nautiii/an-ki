# UX backlog — audit of 2026-10-07

Living list of what to improve, from a full audit with the snapshot tool (light, dark, 200 % text,
360×640) and the palette audit. The current UI is a **draft, not a constraint**: the "big bets"
below deliberately question structure, not just polish.

Evidence: regenerate with the snapshot tool (home, home_empty, birthday_form, loading,
scanner, settings, auth). Shipped items are gone (git history holds them); device checks still
owed are in architecture `migration.md` §1.

Rules: verify an item still exists before acting (code moves); delete items you fix; add what you
find (one line, evidence, priority). Big bets and anything touching the data model, navigation,
auth or dependencies → design brief + maintainer approval first.

Ids (B, D, F, Q, S) are this backlog's; elsewhere cite them as « ux D17 ». The architecture decisions D1–D14 live in `architecture/references/decisions.md` and are cited « decision D9 ».

## Contents
- Big bets (B4's gift ideas, deferred; B8; B9 Livres, approved, and B9-ext) — structural redesigns with the highest impact
- P2 — polish (D17, D28, D29)
- Suggested roadmap

---

## Big bets

### B4 — Gift ideas per person (deferred)
- **Deferred** (maintainer, 2026-11-03: a good idea, for later, not now). Reframed 2026-11-08
  (decision D13): Livres is its own module (B9), B4 becomes an **extension of the Anniversaires
  module**: a feature `ideas` depending on `birthday` (graph `ideas: {auth, birthday}`), no tab.
  Ideas live on the person page (B4c: a slot built by `ideas`, passed by `app/router`, no edge
  from `birthday`), in an inbox « à trier », and on the J-0 hero (« Idée cadeau »); « 2 idées pour
  Léa » in the J-7 notification (B4d, needs B8 step 2). Settled in the briefs of 2026-11-01 and
  2026-11-08, to reuse when it starts:
  - `Idea` in `user/{uid}/ideas/{id}`: `title`, optional `personId` (absent = the inbox; an id no
    longer in the agenda falls back to it, no cascade write), `url`, `isbn`, `authors`,
    `imageUrl`, `createdAt`; owner-only rules tested in the emulator first; erased by the
    Anniversaires module's eraser; ordered by `createdAt`, no composite index;
  - pure `parseIdeaText` (the first http(s) word is the link) and `groupIdeas` (inbox, then
    people by next birthday);
  - its ISBN input reuses the ISBN reader and lookup, **promoted to `core/` the day B4 starts**
    (rule of two), never an edge `ideas -> books`;
  - the legacy `books` documents now belong to Livres (B9), not to B4;
  - `url_launcher` approved (2026-11-03) to open a link.
- **Refs**: Apple/Google Contacts cards, wishlist apps, Pinterest boards (lightweight).
- **Cost**: medium (ideas model and rules, the person-page slot, the inbox, the ISBN input).

### B9 — Livres module (approved 2026-11-08)
- **Approved** as a system change (brief of 2026-11-08, every default accepted): an independent,
  user-toggleable module, off by default (decision D13), tracking manga and BD series; metadata
  and dates per decision D14. Data under `user/{uid}/bookSeries` and `user/{uid}/bookVolumes`
  (decision D8, amended). The settled design, condensed:
- **Jobs and screens**:
  - Browse (frequent, at the shelf): `/books`, the shelf: search, an « À classer (n) » card when
    needed, series A to Z, each row with the cover, the name, the **last volume in big digits**
    (S6) and a « prochain » line with the gaps. `/books/series/:id`: last volume, a « Prochain :
    tome 109 » card (date, source, check date), « Il vous manque 13, 14 », the number grid (owned
    filled, missing outlined). TalkBack reads one sentence per row.
  - Add (under 10 s after the purchase): `/books/scan`, a pushed page (the camera runs only
    while scanning, no mounted tab): burst mode, each volume stacks at the bottom
    (« ✓ One Piece · tome 108 »), `lightImpact` per added volume, « Déjà dans votre collection »
    without vibration, « Saisir un ISBN », « Terminé ». Sheet « Ajouter une série »: a name (with
    suggestions), « J'ai les tomes 1-12, 15 », « Série terminée ».
  - Correct: a volume's sheet (change series or number, remove with Undo), a series menu (rename,
    merge with Undo, mark complete, delete with Undo).
  - `/books/series/:id`, `/books/scan` and `/books/inbox` are sub-routes on the root navigator,
    above the bar.
- **States**: first launch = the moon (S2), « Scanner un livre », « Ajouter une série à la main »;
  loading = skeleton; error = message and « Réessayer »; offline = a discreet « Hors ligne ·
  dates non actualisées » banner, never blocking reading; dark, 200 % (rows stack, the grid
  drops columns), 360×640. Before coding the shelf, compare at least two layouts in snapshots (A
  to Z with search, Contacts-like, against sections by status, Things-like); the default is A to Z.
- **Domain (pure Dart, tested)**:
  - `Series`, `Volume` (series and number optional, ISBN, title, cover, publisher, lookup
    `pending`/`found`/`notFound`, `addedAt`); whole numbers only: a « tome 10.5 », a special or a
    box set stays « à classer » with its title;
  - `shelfOf(series, volumes)`: owned, last, **gaps**, next to buy (the first gap, else last + 1),
    cover of the last owned;
  - `nextVolumeStatus(series, today)`: `released`, `announced` (day or month), `unknown`,
    `complete`;
  - `guessVolume(record)`: the BnF structured fields first (225 `$a`/`$v`, 461 `$t`/`$v`, high
    confidence), else the title (« Tome 108 », « T15 », « Vol. 3 », « #12 », « n° 4 », number first,
    roman numerals); « Édition originale » dropped, « Perfect Edition », « Deluxe » and
    « Colossale » kept (other series); nothing sure = « À classer »;
  - `seriesKey(name)` folds a name to match a scan to a series, old names after a rename or merge
    included (`foldForMatching`, promoted from `birthday` to `core/text/`, no copy and no edge);
    `parseVolumeRanges('1-12, 15')`; `normalizeIsbn` (dashes out, ISBN-10 to 13, check digit).
- **Data**: `bookSeries/{id}`: `name`, `keys`, optional `complete`, optional `next` (`number`,
  `status`, `date` as the string `2026-12-03` or `2026-12`, `source` in `bnf`/`googleBooks`/`user`,
  `checkedAt`), `createdAt`. `bookVolumes/{id}`: optional `seriesId`, `number`, `isbn`; `title`,
  `authors`, `imageUrl`, `publisher`, optional `publishedDate`, `lookup`, `addedAt`; **id = ISBN**
  for a scanned volume, so a rescan, offline or from two devices, rewrites the same document. No
  stored summary (size, Google ToS). Owner-only rules plus `delete` by the marked address (guest
  takeover, like `categories`), proved in the emulator first; two full streams, no index, joined
  by `shelfOf`. Eraser: both collections and the legacy `books`. Guest takeover: server read and
  marks before sign-in, copy under the target account, same-key series merged, owned ISBN
  skipped. Legacy `books`: lazy import at the first opening of the Livres tab (server read, pure
  plan with duplicates merged and `guessVolume`, batch write with `importedAt` on each old
  document; idempotent, offline = retry; cleanup in `migration.md`).
- **Offline**: reading from the Firestore cache; missing covers replaced by initials on a tonal
  container and a big number (no new package, measured in store). A scan offline writes the
  volume at once (`lookup: pending`, id = ISBN) and counts in the burst (« ISBN 978… · infos à
  compléter »); Firestore is the queue; at the next online opening of Livres a completer looks up
  BnF then Google, attaches a series or leaves « à classer », a network error stops the pass
  without marking anything « introuvable ». No connectivity package.
- **Release dates** (decision D14): the user's entry (« Ajouter la date »); the BnF for « paru »
  (« Tome 109 paru · vous ne l'avez pas »); Google Books for « à paraître » only if a measurement
  on the phone justifies it (title and number search validated by `guessVolume`, day or month,
  « selon Google Books · vérifié le … »); else « Tome 109 · date inconnue ». Never estimated,
  never scraped. Refresh on opening the shelf, online, series checked over 7 days ago (20 at
  most), plus pull to refresh on a series; cached in the series' `next`; no background task.
- **Navigation and start**: nothing runs at startup, even when active; the completer, the legacy
  import and the refresh start when its screens open; data providers are `autoDispose`. A single
  discovery card after the agenda (« Essayer » turns the module on and opens `/books`, « Plus
  tard » stores `books: false`), never above the hero nor at first launch.
- **Commit steps** (each green: format, analysis, tests, review; steps 1 to 5 are the modules
  lot: docs, registry, data hooks, activation, rename). Step 4 built on 2026-11-09: Réglages ›
  Modules (`/settings/modules`, a switch per module, « Toujours actif », « Effacer les données
  Livres… »), no bar with one module, the redirect snackbar; the tab already reads « Livres »
  with a book icon, over the old scanner until step 7.
  Step 7 built on 2026-11-10 (A to Z list kept: 62/65 on the rubric against 44 for sections by
  status): `/books` shelf (app bar « Livres », scan action, settings avatar; search; « À classer
  (n) »; rows with cover or initials, S6 last volume, « Prochain : tome N · … » from
  `nextVolumeStatus`, « Il vous manque … », one TalkBack sentence); `/books/series/:id` (header,
  « Prochain » card with source and check date, holes as chips, number grid, menu: rename,
  merge and delete with Annuler, mark complete or ongoing with Annuler; unknown id message);
  the volume sheet (classify, remove with Annuler); `/books/inbox`; `/books/scan` pushed on the
  root navigator, single scan as before, its own camera-denied and camera-unavailable states;
  first run (moon, « Scanner un livre »; « Ajouter une série à la main » since step 8),
  skeleton, error with retry, offline banner after 3 s on the cache only. The carousel and
  `scannedVolumesProvider` are gone.
  Step 8 built on 2026-11-11: `/books/scan` in burst (the camera stays on; a code re-read in
  the same burst is ignored; an owned ISBN shows « Déjà dans votre collection · One Piece 107 »
  without vibrating; each new volume stacks newest first: « ✓ One Piece · tome 108 », « ISBN …
  · infos à compléter », « <titre> · à classer », « Introuvable · Classer »; a tap opens its
  sheet, or the classify sheet for « Introuvable »; `lightImpact` and a 300 ms check, none under
  reduce motion; torch, « Saisir un ISBN » sheet checked by `normalizeIsbn`, « Terminé »). A
  low-confidence guess stays « à classer »: attaching it with a « vérifier » hint would put a
  wrong number into a series' last volume and gaps, the job people open the shelf for, and the
  row already says « à classer ». « Ajouter une série » sheet (name with the existing series as
  chips, joins a series of the same key, « J'ai les tomes » with typed errors, « Série
  terminée »), from the first run and an app-bar button, then the series page. Pending volumes
  are completed when a Livres page opens and on resume. The single-scan sheet is gone.
  6. `FEAT(books): series and volumes`: domain, repositories (Firestore, BnF, Google), rules,
     emulator tests and deployment, eraser and guest transfer, legacy import;
  7. `FEAT(books): shelf and series pages`: shelf, series page, volume sheet, « À classer », the
     scanner as the pushed `/books/scan`, states, accessibility, snapshots;
  8. `FEAT(books): burst scanning and corrections`: burst, duplicate guard, ISBN entry, offline
     queue and completion, manual add by ranges, move/renumber/remove/rename/merge/complete;
  9. `FEAT(books): next volume release`: the Google Books measurement first, then BnF « paru »,
     Google « à paraître » if kept, manual entry, cache and refresh;
  10. `FEAT(app): discover the books module`: the discovery card.
- **Verification**: tests at every layer, rules in the emulator (step 6), snapshots (steps 7 to 10),
  `device-runner` (dark, 200 %, airplane mode). A real scan needs the phone's camera: the emulator
  can't present a barcode.
- **Out of the lot**: Birthdays that can be turned off, the « Plus » tab, a disk cache for covers,
  summaries, a wishlist, prices, loans, sharing a collection, an Android shortcut, scraping and
  partnerships, export.
- **Risks**: the series heuristic will sometimes be wrong (one-gesture correction, a renamed
  series keeps its old name as a key); dates will be rare (hence manual entry and the measure);
  Google ToS on permanent copies (store the minimum, BnF first); a privacy policy before any
  publication.
- **Cost**: large (five commits of size M to L after the modules lot).

### B9-ext — Release reminders (outside this lot)
- A local notification on the day of an announced release (or the eve), through the combined
  plan of decision D13 (revisit): an id range of its own, payload `books:<seriesId>` opening the
  series. To propose after the Livres lot, once the reliability of the dates is measured.
- **Cost**: medium (the combined notification plan in `app/`, the Books planning rule, tests).

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

## Suggested roadmap

1. **B8, D17, D28** — depth and polish (D29 if it matters);
   natural-language quick add (« Léa 12 mars ») once the typed date proves the bottleneck.
2. **B9 Livres** — approved 2026-11-08, in progress: modules, then series, shelf, burst scan,
   release dates, discovery card; **B9-ext** (release reminders) proposed after it.
3. **B4's gift ideas** — an Anniversaires extension, when the maintainer picks them up.
