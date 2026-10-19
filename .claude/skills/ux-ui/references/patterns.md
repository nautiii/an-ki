# Pattern catalog — what the best apps do, applied to AnKi

For each use case: the recommended AnKi pattern, the references that prove it, the Flutter
building blocks, and what to avoid. Treat it as a strong default, not a cage: if the task reveals
a better pattern, score it with the rubric in SKILL.md and explain the choice.

## Contents
- A. Structure: navigation, sheets vs pages vs dialogs
- B. Home — "who's next"
- C. Capture a birthday (core flow)
- D. Edit, delete, quick actions
- E. Search & filters
- F. Calendar
- G. Empty, loading, error, offline states
- H. Onboarding, auth, permissions
- I. Reminders & retention (ethical)
- J. Settings
- K. Gift ideas / scanner
- L. The birthday moment (celebration)
- M. 2025–2026 trends — adopt, adapt or skip
- N. UX laws cheat sheet

---

## A. Structure

**Navigation** — floating glass pill (identity S5) with ≤ 4 destinations, icon + label.
- Labels: with 2–3 destinations show both labels (clearer, and TalkBack needs them); the
  "selected-only label" style is acceptable only if every item keeps a semantic label + tooltip.
- Refs: Spotify / Instagram bottom tabs; iOS 26 floating tab bar; M3 `NavigationBar`.
- Flutter: custom pill today; `NavigationBar` + `NavigationDestinationLabelBehavior` if it's
  ever rebuilt; `Semantics(selected: …)` on items.

**Choose the container** (Material + Apple HIG agree):

| Need | Pattern | AnKi examples |
|------|---------|---------------|
| Quick create/edit, ≤ ~6 fields, keep context | Modal bottom sheet (drag handle, `useSafeArea`, CTA pinned above keyboard) | Add/edit birthday, new category, day details |
| Rich content, deep linkable, long forms, multi-step | Full page with large title (`SliverAppBar.large`) | Person detail (future), settings |
| Blocking decision, irreversible | Dialog (title = question with object, destructive button named by action) | Delete account, sign out as guest |
| Transient feedback, undo | Floating `SnackBar` + `SnackBarAction` | Deleted · Annuler, Saved |
| Persistent state needing action | `MaterialBanner` / inline card | Notifications disabled, sync pending |
| Contextual secondary actions | `MenuAnchor` (long-press / ⋯) | Share, duplicate, mark as wished |

Avoid: forms in dialogs, sheets stacked on sheets, full-screen spinners, new routes for one field.

## B. Home — "who's next"

The home answers one question in < 2 s: *who, when, how old*. Pattern = **hero + time-bucketed
agenda** (Netflix billboard + Todoist Upcoming / Google Calendar schedule).
- **Hero** (S1): next birthday(s); several on the same day → stacked cards, each with its own
  state (§L, `next_birthday.dart`); content: avatar, name, « aujourd'hui / demain / dans N jours »,
  « aura N ans », moon phase (S3); on the day « Souhaiter » + « Déjà souhaité » (§L, shipped in
  step 4), « Idée cadeau » in the week before with B4.
- **Agenda list** grouped by time: « Dans les 7 jours », then one section per month
  (« Novembre », « Janvier 2027 ») — chunking (Miller) that holds for a whole year, where
  « Plus tard » would become a flat list again. Sticky section headers. Each row: avatar ringed
  with the person's category tones, name, « 9 octobre · aura 34 ans », moon + « J-12 » badge.
  The birth year is noise here.
- Greeting personalised by time of day (Spotify « Bonsoir ») is a cheap warm touch; keep it short.
- Refs: Todoist *Upcoming*, Apple Reminders *Today/Scheduled*, Google Calendar *Schedule*,
  Facebook birthdays (today first + quick wish).
- Flutter: `CustomScrollView` + `SliverMainAxisGroup` per section with a pinned
  `SliverPersistentHeader`; grouping in a domain rule (`agenda()`) wired by `agendaProvider`.
  Shipped in step 2: `home_screen.dart`, `agenda_list.dart`, `agenda_tile.dart`.
- Avoid: one flat list sorted by name, the birth year as main metadata, more than one hero.

## C. Capture a birthday (core flow — make it < 10 s)

**Quick-add sheet** (Google Calendar quick event, Todoist Quick Add, Google Contacts' optional
year). Shipped in step 3: `birthday_form_sheet.dart`, `birth_date_field.dart`; the flow is « + »,
the name, « Suivant », four digits, « OK ».
1. Name — **one field** « Prénom et nom », `autofocus`, `TextCapitalization.words`,
   `textInputAction: next` to the date. Split on save (`BirthdayDraft.splitFullName`: first word =
   first name, the rest = last name), so « Mamie » works and the model keeps two fields. No
   `autofillHints`: they would offer the user's own name.
2. Date — typed, **day + month required, year optional**: `TextInputType.datetime`, slashes
   inserted while typing (`maskBirthDateInput`), tolerant reading (`parseBirthDate`: « 1203 »,
   « 1/3 », « 12.03.1990 » — Postel), live preview under the field (« Le 12 mars 1990 · aura
   37 ans ») and precise errors (no such date, incomplete year, future date). An unfinished input
   is a neutral hint while typing and an error once the field is left. Never default to « today −
   25 years », never a wheel or picker that forces the year.
3. Avatar beside the name: live initials, tap → photo (never the first thing in the form).
   Categories on one scrolling row of `FilterChip`s, icon in the category tone replaced by the
   check once selected, « Nouvelle catégorie » last.
4. CTA enabled as soon as name + day/month are valid; keyboard « OK » saves; `lightImpact` on
   save. Editing reuses the sheet, prefilled (« 15/10 » for a yearless birthday).
- Without a year no age is shown anywhere (agenda line, hero, calendar day sheet): never an
  invented one.
- Bulk path: **import from contacts** is the fastest value. Shipped in step 5.2: the empty home
  is the invite (« Choisir dans mes contacts » first, a line on what AnKi reads), and
  `contact_import_screen.dart` (also opened from Settings) asks for access on arrival, then lists
  the contacts pre-checked, soonest first, with those already in AnKi apart and not importable
  (`previewContactImport`: same name up to case, accents and dashes, same day). Denied →
  « Autoriser l'accès »; blocked → « Ouvrir les réglages », re-read on return.
- Stretch: natural-language single field « Léa 12 mars » (Todoist) parsed by a domain rule.
- Avoid: photo picker as the first thing in the form, required fields that aren't needed to
  remind, validation only after pressing save, a date control that forces the year.

## D. Edit, delete, quick actions

- Tap row → edit sheet (or person detail later). Long-press → `MenuAnchor` with contextual actions.
- **Delete = undo, not confirm** (Gmail): swipe (end-to-start) or menu → item disappears with a
  `mediumImpact` → floating snackbar « Anniversaire de Léa supprimé · Annuler » (≥ 4 s, longer
  when `MediaQuery.accessibleNavigationOf`). The Notifier keeps the deleted item until the snackbar
  closes, then commits (or restores).
- Swipe start-to-end = positive quick action (« Souhaiter » / « Marquer comme souhaité », mint).
  Every swipe action also exists in the menu (swipes are invisible to many users and to TalkBack:
  add `CustomSemanticsAction`s).
- Confirm dialogs only for irreversible, high-impact or bulk actions (delete account).

## E. Search & filters

- Full-screen search (`AppRoutes.search`, `birthday_search_screen.dart`) that filters live, with a
  clear button and its tooltip; still missing: matched text highlighted in results (Q6).
- Filters: horizontal `FilterChip` row (Airbnb, Google Photos, Spotify home chips) — selected state
  shows a checkmark or filled tone, not color alone; a « Tout » chip resets. Multi-select AND/OR
  semantics must be obvious (« Famille + Amis » = union).
- No results → « Aucun résultat pour « Lé » » + CTA « Ajouter « Lé » » prefilled (Notion/Linear
  create-from-search): zero dead ends.
- If the list grows (100+), upgrade to `SearchAnchor` with recent searches.

## F. Calendar

- Month grid **aligned on weekdays** with a header row of narrow weekday names, first day from
  `MaterialLocalizations.of(context).firstDayOfWeekIndex` (Monday in FR). Today = ring; days with
  birthdays = dot(s) or count badge using category tones (≥ 3:1) + `Semantics` label
  « 9 octobre, 2 anniversaires ».
- Swipe between months, « Aujourd'hui » chip when away from the current month, tap a day →
  bottom sheet with that day's people.
- Refs: Google Calendar month view, Apple Calendar.
- Avoid: grids that start on the 1st regardless of weekday (the grid follows the locale's first
  weekday), color-only markers.

## G. Empty, loading, error, offline

| State | Pattern | Refs |
|-------|---------|------|
| First run (no data) | Moon mascot (S2) + « Vos anniversaires vivront ici » + why + primary « Ajouter un anniversaire » + secondary « Importer mes contacts » | Dropbox, Duolingo, Headspace |
| No results (search/filter) | Short message + reset filters / create-from-search | Notion, Airbnb |
| Loading | Skeleton shaped like the content (hero + 4 rows), subtle pulse, no shimmer when reduce-motion | Facebook, LinkedIn, Netflix |
| Saving | Optimistic UI (Firestore writes locally first): update instantly, disable only the triggering control | Gmail, Linear |
| Error (recoverable) | Inline message + « Réessayer »; keep user input | Google apps |
| Offline | Quiet banner « Hors ligne — vos changements seront synchronisés », never block reading | Google Docs, Spotify |

A spinner is acceptable only inside the control that triggered a short action.

## H. Onboarding, auth, permissions

- **Value first, account later** (Duolingo lazy sign-up), shipped in step 5.1: signed out lands
  on the welcome (`welcome_screen.dart`) — one promise on the night hero, « Commencer » opens an
  anonymous session at once, « J'ai déjà un compte » pushes the sign-in above it. Ask to save
  the account at a moment of value (from 3 birthdays, or before reinstall risk), never as a wall.
- The sign-in (`auth_choice_screen.dart`, « Bon retour ») offers Google (one tap) › e-mail ›
  sign-up; no guest there. Locked by the fingerprint, it stands alone, prompts at once and puts
  « Déverrouiller » first so a dismissed prompt can be retried.
- No intro motion: the CTAs are there from the first frame; layouts scroll on small screens.
- **Permission priming** (Duolingo, Instagram): before the system prompt, a sheet explains the
  benefit in one line (« Pour vous prévenir 7 jours avant et le jour J ») with « Autoriser » /
  « Plus tard ». Ask in context (notifications after the first birthday is added; contacts when the
  user taps import). If denied: explain how to enable, link to settings, never nag twice a week.

## I. Reminders & retention — ethical hooks

People come back when AnKi saves them from forgetting and makes them look thoughtful.
- Notification copy is personal and actionable: « Demain, Léa fête ses 30 ans 🎂 ». The J-0
  notification carries « Souhaiter » (shipped in step 4, Android: `AndroidNotificationAction`
  with the birthday id as payload; `app/bootstrap` goes home and opens the share sheet).
  « Idée cadeau » on J-7 comes with B4.
- No age in a repeating notification: reminders repeat yearly (`DateTimeComponents.dateAndTime`)
  with the text written when scheduled, so an age goes stale if the app isn't reopened for a year.
  Today's texts carry none. Bringing it back means scheduling each occurrence as a one-shot
  (exact age for the next one, an ageless yearly fallback after it), within iOS's 64 pending
  notifications; `ReminderNotification.age` is still computed for that.
- Cadence: J-7 + J-0 (current) + optional J-1; per-person mute; quiet hours.
- Weekly digest (opt-in) « Cette semaine : 2 anniversaires » — Monday morning.
- Close the loop: « Souhaité » → mint check, light haptic, « Annuler » (peak-end rule; §L).
- Yearly recap (Spotify Wrapped spirit) « Votre année en anniversaires » — shareable, delightful.
- Home-screen widget (native, future) for the next birthday.
- Forbidden: guilt copy (« Vous avez oublié… »), fake urgency, streak pressure, re-engagement
  spam, hiding account deletion.

## J. Settings

Grouped sections with headers, instant apply, danger last (iOS Settings, recent Android settings
with grouped rounded containers):
1. **Profil** — avatar, pseudo (edit inline, save on submit with a check, no separate button).
2. **Préférences** — Thème `SegmentedButton` Système / Clair / Sombre (default Système);
   Langue `SegmentedButton` FR / EN (2 options don't deserve a dropdown).
3. **Rappels** — notification toggles and times.
4. **Données** — Importer mes contacts, Exporter (future).
5. **Sécurité** — Biométrie.
6. **Zone sensible** (separated, error color only on the destructive row) — Se déconnecter,
   Supprimer mon compte (dialog naming the consequence).
Every switch row is fully tappable (`SwitchListTile`), subtitles explain the effect.

## K. Gift ideas / scanner

- Camera viewfinder with a framing guide and one-line instruction; **auto-detect** (no shutter),
  `lightImpact` + result bottom sheet (Yuka, Google Lens).
- Torch toggle, and a **manual ISBN entry** fallback (accessibility, damaged barcodes).
- Results attach to a person (« Idée pour Léa ») — the scanner serves job 2 (act on a birthday).
- Name the tab by its value (« Idées cadeaux »), not its mechanism (« Scanner »).

## L. The birthday moment

Shipped in step 4 (`next_birthday.dart`, `birthday_wish.dart`, `blossom_rain.dart`,
`birthday_wisher.dart`). On J-0 the hero switches to **celebration**: S1 celebration gradient,
full moon + « Aujourd'hui 🎉 », the age (S6), and S4 petals once per person per day (2.4 s,
`mediumImpact`, nothing with reduce motion).
- « Souhaiter » (filled, `onCelebration` / `onCelebrationAction`) opens the system share sheet
  (`share_plus`) with a ready message in the user's voice (« tu »), editable in the app chosen.
  Once an app is chosen the birthday is marked wished — Android reports the app chosen, not the
  sending, hence « Annuler ». A sheet closed without a choice changes nothing.
- « Déjà souhaité » (text button) marks it at once, for a call or a wish in person.
- Then the mint « ✓ Souhaité » pill takes the buttons' place, at their height: the card doesn't
  jump. Snackbar « Anniversaire de Léa souhaité · Annuler » (`lightImpact`).
- Several birthdays today → stacked cards, each with its own state. The person's identity stays
  one button (opens the sheet); the actions are separate targets for TalkBack.
- Model: `wishedYears` (`arrayUnion` / `arrayRemove`), rule `BirthdayWishes.isWished(today)` —
  the year of the latest birthday, so a belated wish on 1 January counts for 31 December.
- Later: « Idée cadeau » (B4), a belated wish (D15).

## M. 2025–2026 trends — adopt, adapt or skip

| Trend | Verdict for AnKi |
|-------|------------------|
| **Material 3 Expressive** (springs, shape contrast, emphasized type, floating toolbars, button groups) | **Adapt the principles** with core Flutter: springs for drag/dismiss, bolder type for the key number, squircle/shape contrast. Flutter core is not implementing M3E; community packages (`material_3_expressive`, `m3e_core`) exist — never add one without the maintainer's approval. |
| **Liquid Glass** (iOS 26 translucent floating chrome) | Already echoed by the nav pill. Glass stays limited to floating chrome. |
| Edge-to-edge (enforced from Android 15) & predictive back | Adopt: `SafeArea` everywhere, transparent system bars with correct icon brightness per theme; Flutter's default Android transition (3.44+) is `PredictiveBackPageTransitionsBuilder` — enable `android:enableOnBackInvokedCallback="true"` in the manifest to get the gesture preview. |
| Skeletons, optimistic UI, micro-interactions + haptics | Adopt (G, identity §8–9). |
| Natural-language / AI-assisted input | Adapt later: « Léa 12 mars » quick add (C). No chatbot. |
| Bento-grid dashboards | Skip for the home (agenda beats tiles for time); possible for a yearly recap. |
| Dynamic color (wallpaper) | Skip: the night indigo is the brand. |
| Material/Cupertino moving out of core (`material_ui` / `cupertino_ui`, announced with 3.44; in-framework Material still not deprecated in 3.47) | Separate migration task, never inside a UI change. |

## N. UX laws cheat sheet

- **Jakob** — users expect AnKi to work like the apps they use daily → conventions in controls.
- **Hick** — fewer choices, faster decisions → one primary action per screen/sheet.
- **Fitts** — big, close targets → bottom CTAs, full-width rows tappable, ≥ 48 dp.
- **Miller / chunking** — group long lists (time buckets, settings sections).
- **Doherty** — respond in < 400 ms → optimistic UI, skeletons, instant feedback.
- **Tesler** — complexity moves to the system → smart defaults, parsing, inference.
- **Postel** — be liberal in what you accept (dates in many formats), strict in what you display.
- **Peak-end** — end flows on a high (success state, celebration), soften the worst moment (undo).
- **Aesthetic-usability** — polish buys tolerance, but never hides a broken flow.
