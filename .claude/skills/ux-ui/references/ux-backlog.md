# UX backlog — audit of 2026-10-07

Living list of what to improve, from a full audit with the snapshot tool (light, dark, 200 % text,
360×640) and the palette audit. The current UI is a **draft, not a constraint**: the "big bets"
below deliberately question structure, not just polish.

Evidence: regenerate with the snapshot tool (home, home_empty, birthday_form, calendar, loading,
scanner, settings, auth). Roadmap steps 1 (F2, F3, A1–A8), 2 (B1, Q1, Q2, A9) and 3 (B2)
shipped on 2026-10-12, step 4 (B3, D7) and steps 5.1–5.2 (B5 welcome and contacts import, Q5)
on 2026-10-18, steps 5.3 (B5 reminders in context, D19 for the J-0 notification) and 5.4 (B5
guest backup) on 2026-10-19, small fixes D6, D19, D20 and D21, Q6 and D18, and the e-mail
sign-in and sign-up forms (D3, their part of F5) on 2026-10-24: the items they fixed are gone
from this list.

Rules: verify an item still exists before acting (code moves); delete items you fix; add what you
find (one line, evidence, priority). Big bets and anything touching the data model, navigation,
auth or dependencies → design brief + maintainer approval first.

## Contents
- Big bets (B4, B6, B7; B5 shipped but its merge) — structural redesigns with the highest impact
- Foundation (F1, F4, F5) — design system, prerequisite for consistency
- P1 — friction & states (Q4, Q7, Q8, Q9)
- P2 — polish (D1, D4, D8–D17, D22)
- Suggested roadmap

---

## Big bets

### B4 — Person page (view-first) + gift ideas per person
- **Problem**: tapping a person opens the edit form (most taps mean « show me », not « edit »).
  The « Scanner » tab names a mechanism; scanned books aren't linked to anyone.
- **Proposal**: tap → person page (large avatar, countdown moon, age, date, groups, notes, gift
  ideas, wish history, per-person reminders; actions Souhaiter / Modifier). Tab 2 → « Idées »:
  ideas per person + an unassigned inbox; add by text, link or ISBN scan (the scanner becomes one
  input). J-7 notification: « 2 idées pour Léa ». « Idée cadeau » also joins the J-0 hero and
  the J-7 notification (step 4 left it out); the page shows the wish history (`wishedYears`) and
  undoes a wish once the snackbar is gone.
- **Refs**: Apple/Google Contacts cards, wishlist apps, Pinterest boards (lightweight).
- **Cost**: medium-high (ideas model with `personId`, navigation, scanner integration).

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
  those 14 names: custom groups all share the neutral tone, so all their rings look alike.
- **Proposal**: « Groupes » with 4 sensible defaults (Famille, Amis, Travail, Autres); create
  inline from the form's chip row (« + Nouveau groupe »); filters only when ≥ 2 groups are used;
  a tone picked per group (`LabelTones` seeds, identity §3.4).
- **Cost**: low-medium.

## Foundation

- **F1 — Bundle Outfit** (recipes §3): offline-correct typography, real weights (today
  `copyWith(fontWeight:)` fakes bold), deterministic snapshots. Needs font download approval.
- **F4 — Theme mode « Système »** as default (today a binary switch derived from the user doc).
- **F5 — Finish the token migration** in the screens step 1 didn't touch: `AnKiTextField` (own
  radii and sizes instead of the input theme), `BookCard` (`BorderRadius.circular(24/12)`, faux
  bold), the « Mettre à jour le pseudo » button in `settings_screen.dart` (radius 16).

## P1 — friction & states

- **Q4 Settings**: flat list; binary theme switch; dropdown for 2 languages; separate « Mettre à
  jour le pseudo » button; destructive actions mixed with preferences → grouped sections, segmented
  controls, instant apply, danger zone (patterns J).
- **Q7 Category sheet**: save always enabled then errors via snackbar → disable until valid,
  inline guidance.
- **Q8 Reminders off, day after day**: whoever answered « Plus tard » or « Ne pas autoriser »
  sees nothing more until the next import or sign-in, and AnKi's one promise silently fails;
  the way back sits in Settings › Rappels only → the calm card of the step 5 prototypes above
  the hero (« Rappels désactivés · Activer », `e5_rappels_off`), shown once the offer was
  declined, dismissable, never a dialog.
- **Q9 Forgotten password**: « Mot de passe oublié ? » on the e-mail sign-in does nothing
  (`onPressed: () {}`, `login_screen.dart`), so whoever forgot it is stuck → Firebase's reset
  e-mail to the typed address, then a calm « E‑mail envoyé à … »; a new auth action, brief first.

## P2 — polish

- **D1 French typography**: dates now go through `DateFormat`; the ARB strings still use a plain
  space before `?`/`!` (« … avec succès ! », and on
  the login and sign-up forms « Mot de passe oublié ? », « Pas encore de compte ? », « Vous avez
  déjà un compte ? ») → narrow no-break space (U+202F); the sign-in page's copy is done.
- **D4 Haptics**: ad hoc (selection/light/medium mixed) → identity §9 map.
- **D8 Scanner tab**: the « Roman / BD / Cuisine / Tech » chips look like filters but do nothing;
  empty-state title ends with a period (« Aucun livre trouvé. ») → remove or make them real (B4).

- **D9 Compact greeting**: at 360×640 and 130 % text, « Bonjour, Camille » ellipsizes behind the
  three app-bar actions (`home_app_bar.dart`); a longer pseudo does it on any phone.
- **D10 Scanner header**: the scanner tab keeps the old two-line `Header` while the home has the
  pinned app bar → align the two tabs when B4 reworks the scanner.
- **D11 Legacy text fields**: the category sheet, login, signup and settings still use
  `AnKiTextField` (outlined, radius 28, sizes and error line drawn by hand) while the birthday
  sheet uses themed `TextField`s with inline `errorText` → migrate them (Q7 with the category sheet).
- **D12 Month-first locales**: the typed birth date reads day then month in every language (hint
  « DD/MM »); a US user typing « 03/12 » gets 3 December — the live preview shows it, an order
  taken from `DateFormat.yMd(locale)` would remove the trap.
- **D13 Imported years**: contacts imported before 2026-10-12 without a birth year were saved as
  born in 2000 and still show an age; each can be fixed in the sheet (« 12/03/2000 » → « 12/03 »).
  A bulk repair can't tell them from real 2000 births: data migration, approval first.
- **D14 Add confirmation**: saving closes the sheet silently; a birthday months away lands
  off-screen → snackbar « Léa ajoutée » with « Voir » (scroll to the row). Imports are already
  announced by `ReminderPrompt` (`app/bootstrap`, from `birthdayAdditionsProvider`): the same
  place can announce a single add.
- **D15 Belated wish**: at midnight the hero moves on; a birthday missed yesterday can no longer
  be wished from AnKi → a calm « Hier : Léa · Souhaiter » for a day or two, never guilt copy.
- **D16 Petals per run**: « once per person per day » lives in memory (`celebratedTodayProvider`);
  a cold start the same day lets the petals fall again → persist the day if it bothers.
- **D17 iOS wish button**: iOS notifications have no « Souhaiter » (Darwin categories are
  declared at initialization, before the texts are localized) → add a category once iOS builds.
- **D22 Cramped row of the day**: at 360×640 with 130 % text, the « Aujourd'hui » countdown
  leaves a search row of the day about 90 dp, « Léa / Martin / 24 / octobre · / aura / 29 ans »
  on six lines (`agenda_tile.dart`, `search_all` snapshot, 2026-10-24) → stack the row on its
  available width (`LayoutBuilder`), not on the text scale alone.

## Suggested roadmap

1. **Q8** — the reminders-off card, B5's loose end (it shares the agenda's top); B5's 5.5 merge
   once guests with an existing Google account show up.
2. **B4, B6, B7, F1, F4, F5, Q4, Q7, Q9, D1, D4, D8–D17, D22** — depth and polish (F1 any time
   once approved);
   natural-language quick add (« Léa 12 mars ») once the typed date proves the bottleneck.
