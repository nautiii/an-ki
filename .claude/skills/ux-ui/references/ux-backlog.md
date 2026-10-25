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
2026-10-24, then the sign-up's single password (Q11), D24, D9, D22, D12, D14 (its message;
« Voir » waits for B4), D8, F5 and D4 on 2026-10-25: the items they fixed are gone from this
list.

Rules: verify an item still exists before acting (code moves); delete items you fix; add what you
find (one line, evidence, priority). Big bets and anything touching the data model, navigation,
auth or dependencies → design brief + maintainer approval first.

## Contents
- Big bets (B4, B6; B5 shipped but its merge) — structural redesigns with the highest impact
- Foundation (F1, F6) — design system, prerequisite for consistency
- P1 — friction & states (Q10)
- P2 — polish (D10, D13, D15–D17, D25)
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
  undoes a wish once the snackbar is gone. The add confirmation (« Léa est dans vos
  anniversaires », `ReminderPrompt`, D14) gains « Voir », which opens the new page.
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

## Foundation

- **F1 — Bundle Outfit** (recipes §3): offline-correct typography, real weights (today
  `copyWith(fontWeight:)` fakes bold), deterministic snapshots. Needs font download approval.
- **F6 — Error ring on fields**: the input theme has no `errorBorder`/`focusedErrorBorder` and
  its `border` is `BorderSide.none`, so a focused field in error loses its focus ring (login
  e-mail without an address, birthday sheet name); the red label and message remain → error
  borders on the `AppRadii.md` shape in `themes.dart` (theme change, approval first).

## P1 — friction & states

- **Q10 Managing groups**: a group is created in the birthday form (B7) but can't be renamed,
  recoloured or deleted, and the older categories (GOAT, Doggo…) stay on whoever picked them
  (found shipping B7, 2026-10-24) → a « Groupes » page from Settings › Anniversaires: rename,
  tone, delete with « Annuler » (the birthdays drop it); a shared one only leaves the profile.

## P2 — polish

- **D10 Scanner header**: the scanner tab keeps the old two-line `Header` while the home has the
  pinned app bar → align the two tabs when B4 reworks the scanner. Same rework: the book
  carousel's `SizedBox(height: 180)` sits in an `Expanded`, so the cards stretch over all the
  space left (≈ 320 dp at 412×915, `scanner` snapshot, 2026-10-25).
- **D13 Imported years**: contacts imported before 2026-10-12 without a birth year were saved as
  born in 2000 and still show an age; each can be fixed in the sheet (« 12/03/2000 » → « 12/03 »).
  A bulk repair can't tell them from real 2000 births: data migration, approval first.
- **D15 Belated wish**: at midnight the hero moves on; a birthday missed yesterday can no longer
  be wished from AnKi → a calm « Hier : Léa · Souhaiter » for a day or two, never guilt copy.
- **D16 Petals per run**: « once per person per day » lives in memory (`celebratedTodayProvider`);
  a cold start the same day lets the petals fall again → persist the day if it bothers.
- **D17 iOS wish button**: iOS notifications have no « Souhaiter » (Darwin categories are
  declared at initialization, before the texts are localized) → add a category once iOS builds.
- **D25 Stacked row reading order**: once an agenda row stacks (large text, narrow screen),
  TalkBack reads « J-3 » before the name, the countdown sitting above it
  (`agenda_tile.dart`, found with D22, 2026-10-25) → keep the row's order (name, date,
  countdown) in the merged label. Low priority.

## Suggested roadmap

1. **B5's 5.5 merge** once guests with an existing Google account show up.
2. **B4, B6, F1, F6, Q10, D10, D13, D15–D17, D25** — depth and polish (F1 any time once
   approved);
   natural-language quick add (« Léa 12 mars ») once the typed date proves the bottleneck.
