# UX backlog — audit of 2026-10-07

Living list of what to improve, from a full audit with the snapshot tool (light, dark, 200 % text,
360×640) and the palette audit. The current UI is a **draft, not a constraint**: the "big bets"
below deliberately question structure, not just polish.

Evidence: regenerate with the snapshot tool (home, home_empty, birthday_form, calendar, loading,
scanner, settings, auth). Roadmap step 1 (F2, F3, A1–A8) shipped on 2026-10-12, step 2 (B1, Q1,
Q2, A9) the same day: the items they fixed are gone from this list.

Rules: verify an item still exists before acting (code moves); delete items you fix; add what you
find (one line, evidence, priority). Big bets and anything touching the data model, navigation,
auth or dependencies → design brief + maintainer approval first.

## Contents
- Big bets (B2–B7) — structural redesigns with the highest impact
- Foundation (F1, F4, F5) — design system, prerequisite for consistency
- P1 — friction & states (Q4–Q7)
- P2 — polish (D1, D3, D4, D6–D10)
- Suggested roadmap

---

## Big bets

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
  personal copy « Demain, Léa fête ses 30 ans » (the age needs one-shot scheduling, see patterns
  §I).
- **Cost**: medium (notification_service, per-person settings).

### B7 — Groups, simplified
- **Problem**: categories need a separate sheet (suggested + custom + icon grid) with quirky
  defaults (OG's, GOAT, Doggo, Internet…); creating one from the birthday form stacks a sheet on
  a sheet. Colors are tonal per theme (`LabelTones`, ring around each agenda avatar), but tied to
  those 14 names: custom groups all share the neutral tone, so their ring stays invisible.
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

## P1 — friction & states

- **Q4 Settings**: flat list; binary theme switch; dropdown for 2 languages; separate « Mettre à
  jour le pseudo » button; destructive actions mixed with preferences → grouped sections, segmented
  controls, instant apply, danger zone (patterns J).
- **Q5 Auth intro**: staggered fades reveal buttons after up to ~1.8 s → ≤ 600 ms, CTAs visible
  at once (route paths already go through `AppRoutes`, M4).
- **Q6 Search**: results don't highlight the matched letters (the search screen already offers
  « Ajouter « … » » when nothing matches).
- **Q7 Category sheet**: save always enabled then errors via snackbar → disable until valid,
  inline guidance.

## P2 — polish

- **D1 French typography**: dates now go through `DateFormat`; the ARB strings still use a plain
  space before `?`/`!` (« Pas encore de compte ? », « … supprimer l'anniversaire de {name} ? »,
  « … avec succès ! ») → narrow no-break space (U+202F).
- **D3 Motion**: `AnKiFadeIn` (auth, login, signup) ignores reduce motion → `context.motion(...)`.
- **D4 Haptics**: ad hoc (selection/light/medium mixed) → identity §9 map.
- **D6 Predictive back**: manifest flag missing (recipes §10).
- **D7 Age unit**: the hero splits « aura », the number and « ans » → « aura 1 ans » for a baby's
  first birthday; agenda rows already use a plural (`agendaLine`).
- **D8 Scanner tab**: the « Roman / BD / Cuisine / Tech » chips look like filters but do nothing;
  empty-state title ends with a period (« Aucun livre trouvé. ») → remove or make them real (B4).

- **D9 Compact greeting**: at 360×640 and 130 % text, « Bonjour, Camille » ellipsizes behind the
  three app-bar actions (`home_app_bar.dart`); a longer pseudo does it on any phone.
- **D10 Scanner header**: the scanner tab keeps the old two-line `Header` while the home has the
  pinned app bar → align the two tabs when B4 reworks the scanner.

## Suggested roadmap

1. ~~**F2 + F3 + A1–A8** — foundation and accessibility debt~~ — shipped 2026-10-12.
2. ~~**B1 + Q1–Q2** — the home everyone sees daily (A9 with it)~~ — shipped 2026-10-12.
3. **B2** — capture without friction or invented ages (model change).
4. **B3** — the birthday moment and the wish loop (new dependency).
5. **B5** — onboarding that lands on a populated agenda.
6. **B4, B6, B7, F1, F4, F5, Q4–Q7, D1–D10** — depth and polish (F1 any time once approved).
