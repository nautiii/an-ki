# UX backlog — what is left to do

Living list of what to improve, from the audit of 2026-10-07 (snapshot tool: light, dark, 200 %
text, 360×640, palette audit) and the friction review of 2026-11-14. The current UI is a **draft,
not a constraint**: the big bets deliberately question structure, not just polish.

Only open work lives here: shipped items are gone (git history and the decisions hold them),
device checks still owed are in architecture `migration.md` §1.

Rules: verify an item still exists before acting (code moves); delete items you fix; add what you
find (one line, evidence, priority). Big bets and anything touching the data model, navigation,
auth or dependencies → design brief + maintainer approval first.

Ids (B, D, P) are this backlog's; elsewhere cite them as « ux D17 » (P1–P10 are the friction
review's). Architecture decisions live in `architecture/references/decisions.md`, cited
« decision D9 ».

## Contents
- Friction review — what is left of P1–P10
- Big bets — B9 Livres (finishing), B9-ext, B8, B4 (deferred)
- Polish — D17, D28, D29
- Suggested roadmap

---

## Friction review — 2026-11-14, what is left

Method and references: the key flows counted against the friction budgets (patterns §O) and set
against current practice (Nielsen Norman Group, Google's Material 3 Expressive research, widget
quality tiers, Smart Reply, the Android 17 contact picker). Approved by the maintainer on
2026-11-15. Shipped since: P2 (plum cold start), P3 (app shortcuts), P4 + P6 (suggested and late
wishes), P5 (contact link, decision D16), P7 + P8 (quick add), P10 (person page), the error red,
the release icon build.

| Id | Job | Left to do |
|----|-----|------------|
| P1 | See who's next | Home-screen widget (next birthdays, J-0 « Souhaiter »): needs its brief — `home_widget`, native Glance code |
| P2 | See who's next | Cold start **4.1 s** (median of 5, profile build, emulator), over the < 2 s promise: measure on the phone, then profile the start |
| P5 | Wish | « Autre app » in « Autres messages » and on the day-after card (a linked person gets those wishes by SMS only); a « Message » action on the J-0 notification; the Android 17 picker once the app targets API 37; WhatsApp (`wa.me`, E.164 numbers) |
| P9 | Capture | A suggestion when a phone contact gains a birthday — later, once access is granted |
| — | All | Error vs primary by night still close: `#FFB5A0` vs `#FFB2BC`, ΔE 4.1 — option: dark error at tone 75 (`#FFA086`, ΔE 6.9), decide after a device check |
| — | Capture | Android 17 contact picker for a single add: check that a birthday can be requested; Play declaration for `READ_CONTACTS` (the bulk import justifies it) |

Rejected: a vertical feed (Spotify, TikTok) or a bento dashboard for the home — a year of dates
reads better as an agenda; a chatbot; streaks or guilt copy; moving familiar navigation.

---

## Big bets

### B9 — Livres module (approved 2026-11-08, built)
Built 2026-11-09 to 2026-11-15 (modules, shelf, series page, burst scan, release dates,
discovery card, earlier volumes; decisions D13–D15). Left:
- **Deploy the `bookSeries` / `bookVolumes` rules** (step 6; firebase skill, `schema.md` §11).
- Phone checks in `migration.md` §1 — a real scan needs the phone's camera.
- **Out of the lot**: Birthdays that can be turned off, a « Plus » tab, a disk cache for covers,
  summaries, a wishlist, prices, loans, sharing, export; a privacy policy before any publication.

### B9-ext — Release reminders (after Livres)
- A local notification on the day of an announced release (or the eve), through the combined
  plan of decision D13 (revisit): an id range of its own, payload `books:<seriesId>` opening the
  series. To propose once the reliability of the dates is measured.
- **Cost**: medium (the combined notification plan in `app/`, the Books planning rule, tests).

### B8 — The age in reminders (brief 2026-10-25; workmanager approved 2026-11-01)
Step 1 is in (workmanager, daily background replan on Android, `reminders.md`).
- **Left, step 1**:
  - Not proven on a device: a run offline with the app's process dead (the emulator can't show
    it: earlier clock moves left a future « FORCE STOP » exit record).
  - The measure on the Honor: debug APK through `scripts/build_and_deploy.ps1` (no
    `flutter run`, its tab force-stops the app), default battery settings, a daily reading for at
    least 10 days, with 3 days without opening AnKi, a reboot and a time offline. Read
    `period_count`, `last_enqueue_time` and `run_attempt_count` in
    `no_backup/androidx.work.workdb` (`run-as` + sqlite3), plus the standby bucket, the alarm
    count and force-stops (`dumpsys activity exit-info`). Good: +1 per ~24 h (≤ 36 h apart),
    reboot and offline included → step 2. Nothing runs → revisit decision D12.
- **Step 2** (after the measure): one-shots with the age inside a 45-day window, the yearly
  ageless repeat beyond it, on the same ids (`planReminders(…, oneShotUntil:)`,
  `PlannedReminder.repeats`, `ReminderNotification.repeats`); ARB age variants of the two bodies
  (ICU plural, « son premier anniversaire » for 1); `reminders.md` invariants rewritten. Step 3:
  iOS (BGTaskScheduler, with D17).
- **Why**: « Demain, Léa fête ses 30 ans » turns a reminder into a thoughtful wish (patterns §I);
  a yearly repeat keeps its scheduled text, so the age needs one-shots replanned in the
  background. Rejected: one-shot + yearly fallback (Android's `matchDateTimeComponents` drops
  the year, both fire the same day); one-shots replanned at app start only; a native receiver.
- **Risk**: the window's one-shot is the only alarm for that occurrence; aggressive OEMs can
  delay the worker, hence the measure and a wide window.
- **Cost of what's left**: medium (plan and service changes, the measure).

### B4 — Gift ideas per person (deferred)
- **Deferred** by the maintainer (2026-11-03). An **extension of the Anniversaires module**
  (decision D13): a feature `ideas` depending on `birthday`, no tab. Ideas on the person page (a
  slot built by `ideas`, passed by `app/router`), in an inbox « à trier », on the J-0 hero
  (« Idée cadeau »); « 2 idées pour Léa » in the J-7 notification (needs B8 step 2). Settled:
  - `Idea` in `user/{uid}/ideas/{id}`: `title`, optional `personId` (absent = the inbox), `url`,
    `isbn`, `authors`, `imageUrl`, `createdAt`; owner-only rules tested in the emulator first;
    erased by the Anniversaires eraser; ordered by `createdAt`, no composite index;
  - pure `parseIdeaText` (the first http(s) word is the link) and `groupIdeas`;
  - the ISBN reader and lookup **promoted to `core/` the day B4 starts**, never an edge
    `ideas -> books`;
  - `url_launcher` approved (2026-11-03) to open a link.
- **Cost**: medium.

## Polish

- **D17 iOS wish button**: iOS notifications have no « Souhaiter » (Darwin categories are
  declared at initialization, before the texts are localized) → add a category once iOS builds.
- **D28 cold-start theme**: the very first launch on a phone (no theme kept yet) follows the
  system until the profile loads.
- **D29 guest details lost on a merge duplicate**: when a guest's birthday matches one already in
  the Google account, the guest's photo, wished years and own reminders are dropped → fill the
  account record's empty fields from the guest's. Priority: low.

## Suggested roadmap

1. **P1** widget brief; **P5** follow-ups (« Autre app » everywhere first).
2. **B9** rules deploy and phone checks.
3. **B8** measure on the Honor, then step 2; **D17** with iOS.
4. **P2** cold start on the phone; D29 if it matters.
5. **B9-ext** release reminders, then **B4** gift ideas when the maintainer picks them up.
