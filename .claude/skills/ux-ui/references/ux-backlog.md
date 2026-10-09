# UX backlog — audit of 2026-10-07

Living list of what to improve, from a full audit with the snapshot tool (light, dark, 200 % text,
360×640) and the palette audit. The current UI is a **draft, not a constraint**: the "big bets"
below deliberately question structure, not just polish.

Evidence: `build/ui_snapshots/audit-2026-10-07/` (home, home_empty, birthday_form, calendar,
loading, settings, auth — regenerate with the snapshot tool if `build/` was cleaned).

Rules: verify an item still exists before acting (code moves); delete items you fix; add what you
find (one line, evidence, priority). Big bets and anything touching the data model, navigation,
auth or dependencies → design brief + maintainer approval first.

## Contents
- Big bets (B1–B7) — structural redesigns with the highest impact
- Foundation (F1–F4) — design system, prerequisite for consistency
- P0 — accessibility & correctness (A1–A8)
- P1 — friction & states (Q1–Q7)
- P2 — polish (D1–D6)
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
- **Model**: `BirthdayModel.date` → day/month + `int? year` (or `hasYear`), backward-compatible
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
  defaults (OG's, GOAT, Doggo, Internet…), filter chips always on the home, colors not
  theme-aware.
- **Proposal**: « Groupes » with 4 sensible defaults (Famille, Amis, Travail, Autres); create
  inline from the form's chip row (« + Nouveau groupe »); filters only when ≥ 2 groups are used;
  tonal colors per group (identity §3.4).
- **Cost**: low-medium.

## Foundation

- **F1 — Bundle Outfit** (recipes §3): offline-correct typography, real weights (today
  `copyWith(fontWeight:)` fakes bold), deterministic snapshots. Needs font download approval.
- **F2 — Tokens + brand extension + component themes** (assets + recipes §1–2): ends the 11
  radii / off-grid spacing / per-widget `styleFrom` drift; hero becomes dusk/night per theme.
- **F3 — Shared states**: `AnKiEmptyState`, `SkeletonBox`, `AnKiAvatar`, `MoonPhase` (assets)
  adopted on home, calendar, scanner.
- **F4 — Theme mode « Système »** as default (today a binary switch derived from the user doc).

## P0 — accessibility & correctness

- **A1 Unlabelled controls** (TalkBack silent): header calendar/settings buttons (no tooltip),
  the « + » add button (GestureDetector), the unselected nav tab (label hidden), sheet close
  buttons, photo picker. — `core/common/header.dart`, `search_bar.dart`, `bottom_bar.dart`,
  `birthday_form_sheet.dart`, `category_form_sheet.dart`.
- **A2 200 % text breaks layouts**: hero fixed `height: 110` + rows (`next_birthday.dart:233`,
  `:274`), sheet title row (`birthday_form_sheet.dart:190`), search field fixed 48 dp; auth screen
  overflows at 360×640 even at 1.3× (`auth_choice_screen.dart:68`, not scrollable).
- **A3 Contrast**: hero overline/secondary text at `onPrimary` 70 % = 4.1 (L) / 3.9 (D); text at
  9–11 sp (« ANS » 9 sp, countdown badge 10 sp, chip labels 11 sp) → ≥ 12 sp, ≥ 85 %.
- **A4 Tap targets**: search `TextField` is 32 dp tall inside its 48 dp box (the box padding
  isn't tappable); nav items 44 dp tall.
- **A5 Calendar grid ignores weekdays**: no weekday header, the 1st is always in column 1
  (`birthday_calendar.dart`) → wrong reading of dates. Use `firstDayOfWeekIndex`.
- **A6 Category colors** are raw `Colors.*` (1.2–3.0:1 on light surface, same in dark) →
  tonal pairs.
- **A7 Hardcoded strings/colors**: nav labels « Anniversaires »/« Scanner », `userName ?? "..."`,
  `Colors.red` (settings), `Colors.white` spinner (form), `Colors.black54` barrier, white nav fill,
  black shadows.
- **A8 Swipe-to-delete is invisible to TalkBack** (no custom semantics action).

## P1 — friction & states

- **Q1 Delete**: swipe + confirm dialog → undo snackbar (recipes §4); keep a dialog only for
  account deletion.
- **Q2 Empty states**: home shows « Aucun anniversaire trouvé. » with a blank area and an empty
  hero; distinguish first run (moon + add + import contacts) from no-results (reset/create).
- **Q3 Loading**: spinners in hero/home → skeletons shaped like the content.
- **Q4 Settings**: flat list; binary theme switch; dropdown for 2 languages; separate « Mettre à
  jour le pseudo » button; destructive actions mixed with preferences → grouped sections, segmented
  controls, instant apply, danger zone (patterns J).
- **Q5 Auth intro**: staggered fades reveal buttons after up to ~1.8 s → ≤ 600 ms, CTAs visible
  at once (route paths already go through `AppRoutes`, M4).
- **Q6 Search**: no-results dead end → « Ajouter « … » » prefilled; highlight matches.
- **Q7 Category sheet**: save always enabled then errors via snackbar → disable until valid,
  inline guidance.

## P2 — polish

- **D1 French typography**: months capitalised (« 9 Octobre ») and manual date building →
  `DateFormat` (recipes §7); narrow no-break space before `?`/`!`/`:` in ARB strings.
- **D2 Avatars**: generic person icon → initials on stable tones (`AnKiAvatar`).
- **D3 Motion**: no reduce-motion handling anywhere (`AnKiFadeIn`, nav bounce, switches) →
  `context.motion(...)`; bottom-nav bounce tween → spring.
- **D4 Haptics**: ad hoc (selection/light/medium mixed) → identity §9 map.
- **D5 ALL-CAPS overlines** (« PROCHAIN ANNIVERSAIRE », « ANS ») → sentence case labels.
- **D6 Predictive back**: manifest flag missing (recipes §10).

## Suggested roadmap

1. **F2 + F3 + A1–A8** — foundation and accessibility debt (low risk, visible everywhere).
2. **B1 + Q1–Q3** — the home everyone sees daily.
3. **B2** — capture without friction or invented ages (model change).
4. **B3** — the birthday moment and the wish loop (new dependency).
5. **B5** — onboarding that lands on a populated agenda.
6. **B4, B6, B7, F1, F4, Q4–Q7, D1–D6** — depth and polish (F1 any time once approved).
