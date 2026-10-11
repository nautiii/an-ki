# UX backlog — audit of 2026-10-07

Living list of what to improve, from a full audit with the snapshot tool (light, dark, 200 % text,
360×640) and the palette audit. The current UI is a **draft, not a constraint**: the "big bets"
below deliberately question structure, not just polish.

Evidence: regenerate with the snapshot tool (home, home_empty, birthday_form, calendar, loading,
scanner, settings, auth). Roadmap step 1 (F2, F3, A1–A8) shipped on 2026-10-12: those eight scenes
now pass the audit with no finding; the items it fixed are gone from this list.

Rules: verify an item still exists before acting (code moves); delete items you fix; add what you
find (one line, evidence, priority). Big bets and anything touching the data model, navigation,
auth or dependencies → design brief + maintainer approval first.

## Contents
- Big bets (B1–B7) — structural redesigns with the highest impact
- Foundation (F1, F4, F5) — design system, prerequisite for consistency
- P0 — accessibility & correctness (A9)
- P1 — friction & states (Q1, Q2, Q4–Q7)
- P2 — polish (D1, D3, D4, D6–D8)
- Suggested roadmap

---

## Big bets

### B1 — Home becomes a scroll-first « Agenda » (job 1: who's next)
- **Problem**: header + hero + search + filter chips push the first person to y≈412 of 915 —
  less than half the screen shows people. Flat list; rows lead with birth year + current age
  instead of « when » and « how old they'll be ». Calendar hides behind an ambiguous icon toggle.
- **Proposal**: `CustomScrollView` — `SliverAppBar.large` greeting by time of day (« Bonsoir
  Camille ») with avatar → profile/settings; hero (next birthday, celebration on J-0); agenda
  buckets with sticky headers (recipes §5); rows: avatar/initials, name, countdown badge + moon
  phase, « 12 mars · aura 34 ans ». Search = app-bar icon opening `SearchAnchor` (recent
  searches, filters inside); « Agenda | Calendrier » as a segmented control.
- **Refs**: Google Calendar schedule, Todoist Upcoming, Spotify home, iOS large titles.
- **Impact**: first person visible ~100 px higher, scan time down, clear hierarchy.
- **Cost**: medium — `home_screen`, `contact_tile`, `next_birthday`, new `agendaProvider`; no
  data-model change.

### B2 — Express capture, birth year optional (job 3: capture)
- **Problem**: photo first, 2 required name fields, year forced (default « today − 25 years ») →
  the app shows **invented ages** for friends whose year you don't know (trust killer); date
  rendered `12/10/2001`; the date sheet's confirm button says « Ajouter »; validation after submit.
- **Proposal**: quick-add sheet — Name (one field) + day/month (+ « Je connais l'année ») →
  « Plus d'options » (photo, groups, notes); CTA enabled when valid; keyboard flow; success
  snackbar. Ages and « aura N ans » only when the year is known. Later: « Léa 12 mars » parsing.
- **Model**: `Birthday.date` → day/month + `int? year` (or `hasYear`), backward-compatible
  `fromFirestore`, notifications keyed on day/month, age guards.
- **Refs**: Google Contacts (year optional), Todoist Quick Add, Google Calendar quick event.
- **Impact**: add in < 10 s instead of ~25 s; no false information.
- **Cost**: medium-high (model, repository, form, notifications, tests) — approval required.

### B3 — Close the loop: « Souhaiter » + the birthday moment (job 2: act)
- **Problem**: AnKi reminds but doesn't help act. Notifications have no actions; J-0 is just a
  label (« Aujourd'hui 🎉 ») on the same card.
- **Proposal**: J-0 hero in celebration state (identity S1 + S4) with primary « Souhaiter » →
  share sheet / SMS / WhatsApp prefilled with a warm, editable message; then « Marqué comme
  souhaité » (mint ✓) for this year, visible in the agenda. Notification actions « Souhaiter » /
  « Idée cadeau » (`AndroidNotificationAction`).
- **Deps**: `share_plus` or `url_launcher` (new package → approval); `wishedYears` on the model.
- **Refs**: Facebook birthday quick wish, Todoist completion delight, peak-end rule.
- **Impact**: the reason to open AnKi on the day; a satisfying habit loop without dark patterns.

### B4 — Person page (view-first) + gift ideas per person
- **Problem**: tapping a person opens the edit form (most taps mean « show me », not « edit »).
  The « Scanner » tab names a mechanism; scanned books aren't linked to anyone.
- **Proposal**: tap → person page (large avatar, countdown moon, age, date, groups, notes, gift
  ideas, wish history, per-person reminders; actions Souhaiter / Modifier). Tab 2 → « Idées »:
  ideas per person + an unassigned inbox; add by text, link or ISBN scan (the scanner becomes one
  input). J-7 notification: « 2 idées pour Léa ».
- **Refs**: Apple/Google Contacts cards, wishlist apps, Pinterest boards (lightweight).
- **Cost**: medium-high (ideas model with `personId`, navigation, scanner integration).

### B5 — Value-first onboarding
- **Problem**: first launch = auth wall (3 choices), then an empty home with plain text; contact
  import is buried in Settings; notification permission isn't primed.
- **Proposal**: welcome (moon, one promise) → « Retrouver les anniversaires de vos contacts »
  (priming → import preview with checkboxes) → notifications priming (« Prévenu 7 jours avant et
  le jour J ») → populated agenda. Account creation offered later at a moment of value (after a
  few birthdays) as « Sauvegarder mes données »; returning users keep Google/email/biometrics.
- **Refs**: Duolingo lazy sign-up, Headspace/Calm onboarding.
- **Impact**: time-to-value under a minute.
- **Cost**: medium; touches auth flow → approval.

### B6 — Reminders you control
- **Problem**: fixed J-7 + J-0 for everyone; generic J-7 title; no time of day, quiet hours or digest.
- **Proposal**: Settings › Rappels (default cadence J-30/J-7/J-1/J-0, time, quiet hours, optional
  Monday digest « Cette semaine : 2 anniversaires ») + per-person override on the person page;
  personal copy « Demain, Léa fête ses 30 ans ».
- **Cost**: medium (notification_service, per-person settings).

### B7 — Groups, simplified
- **Problem**: categories need a separate sheet (suggested + custom + icon grid) with quirky
  defaults (OG's, GOAT, Doggo, Internet…) and filter chips always on the home. Colors are now
  tonal per theme (`LabelTones`), but tied to those 14 names: custom groups all share the neutral
  tone.
- **Proposal**: « Groupes » with 4 sensible defaults (Famille, Amis, Travail, Autres); create
  inline from the form's chip row (« + Nouveau groupe »); filters only when ≥ 2 groups are used;
  a tone picked per group (`LabelTones` seeds, identity §3.4).
- **Cost**: low-medium.

## Foundation

- **F1 — Bundle Outfit** (recipes §3): offline-correct typography, real weights (today
  `copyWith(fontWeight:)` fakes bold), deterministic snapshots. Needs font download approval.
- **F4 — Theme mode « Système »** as default (today a binary switch derived from the user doc).
- **F5 — Finish the token migration** in the screens step 1 didn't touch: `login_screen`,
  `signup_screen` (ad-hoc `fontSize`, faux bold, raw radii), `AnKiTextField` (own radii and
  sizes instead of the input theme), `BookCard` (`BorderRadius.circular(24/12)`, faux bold),
  `settings_screen.dart:260` (radius 16).

## P0 — accessibility & correctness

- **A9 Calendar cells under 48 dp on small phones**: 7 columns of a 312 dp content width give
  41 dp cells (48 dp from a 392 dp-wide screen). Every cell announces its full date and who is
  celebrated, but the touch target stays small → B1's agenda as the default view, or a week list
  on narrow screens.

## P1 — friction & states

- **Q1 Delete**: swipe + confirm dialog → undo snackbar (recipes §4); keep a dialog only for
  account deletion.
- **Q2 Empty states**: first run now shows the moon + « Ajouter un anniversaire »; still missing:
  « Importer mes contacts » as its secondary action, a real no-results state (search or filters:
  reset / create), and the case where every birthday sits in the hero — the list then says
  « Aucun anniversaire trouvé. » with no search nor filter active (`home_screen.dart`).
- **Q4 Settings**: flat list; binary theme switch; dropdown for 2 languages; separate « Mettre à
  jour le pseudo » button; destructive actions mixed with preferences → grouped sections, segmented
  controls, instant apply, danger zone (patterns J).
- **Q5 Auth intro**: staggered fades reveal buttons after up to ~1.8 s → ≤ 600 ms, CTAs visible
  at once (route paths already go through `AppRoutes`, M4).
- **Q6 Search**: no-results dead end → « Ajouter « … » » prefilled; highlight matches.
- **Q7 Category sheet**: save always enabled then errors via snackbar → disable until valid,
  inline guidance.

## P2 — polish

- **D1 French typography**: dates now go through `DateFormat`; the ARB strings still use a plain
  space before `?`/`!` (« Pas encore de compte ? », « … supprimer l'anniversaire de {name} ? »,
  « … avec succès ! ») → narrow no-break space (U+202F).
- **D3 Motion**: `AnKiFadeIn` (auth, login, signup) ignores reduce motion → `context.motion(...)`.
- **D4 Haptics**: ad hoc (selection/light/medium mixed) → identity §9 map.
- **D6 Predictive back**: manifest flag missing (recipes §10).
- **D7 Age unit**: hero and tiles split the number from « ans » → « 1 » + « ans » for a
  one-year-old; reuse the `ageInYears` plural when B1 reworks the rows (« aura 2 ans »).
- **D8 Scanner tab**: the « Roman / BD / Cuisine / Tech » chips look like filters but do nothing;
  empty-state title ends with a period (« Aucun livre trouvé. ») → remove or make them real (B4).

## Suggested roadmap

1. ~~**F2 + F3 + A1–A8** — foundation and accessibility debt~~ — shipped 2026-10-12.
2. **B1 + Q1–Q2** — the home everyone sees daily (A9 with it).
3. **B2** — capture without friction or invented ages (model change).
4. **B3** — the birthday moment and the wish loop (new dependency).
5. **B5** — onboarding that lands on a populated agenda.
6. **B4, B6, B7, F1, F4, F5, Q4–Q7, D1–D8** — depth and polish (F1 any time once approved).
