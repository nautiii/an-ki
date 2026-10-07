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
- **Hero** (S1): next birthday(s); several on the same day → `PageView`/`CarouselView` with
  page dots *and* swipe hint; content: avatar, name, « aujourd'hui / demain / dans N jours »,
  « aura N ans », moon phase (S3), one primary action when ≤ 7 days (« Souhaiter », « Idée cadeau »).
- **Agenda list** grouped by time: « Aujourd'hui · Cette semaine · Ce mois-ci · Plus tard »
  (chunking, Miller), sticky section headers. Each row: avatar, name, countdown badge first,
  date without year (« 9 octobre »), age they will turn. The birth year is noise here.
- Greeting personalised by time of day (Spotify « Bonsoir ») is a cheap warm touch; keep it short.
- Refs: Todoist *Upcoming*, Apple Reminders *Today/Scheduled*, Google Calendar *Schedule*,
  Facebook birthdays (today first + quick wish).
- Flutter: `CustomScrollView` + `SliverMainAxisGroup` per bucket with a pinned
  `SliverPersistentHeader`; grouping/sorting in a derived provider, never in the widget.
- Avoid: one flat list sorted by name, the birth year as main metadata, more than one hero.

## C. Capture a birthday (core flow — make it < 10 s)

**Quick-add sheet with progressive disclosure** (Google Calendar quick event, Todoist Quick Add).
1. Name — one field, `autofocus`, `TextCapitalization.words`, `textInputAction: next`,
   `autofillHints: [AutofillHints.name]`. Splitting first/last name is friction for friends
   (« Mamie », « Léa »): ask the maintainer before changing the model; at minimum make last name optional.
2. Date — **day + month required, year optional** (Google Contacts). Options, best first:
   a) day/month wheels with a « Je connais l'année » toggle; b) text field `JJ/MM` or `JJ/MM/AAAA`
   accepting `12/3`, `12.03`, `12 mars` (Postel) with live preview « 12 mars »;
   c) `showDatePicker(initialEntryMode: DatePickerEntryMode.input)` only if year is known.
   Never default to « today − 25 years ».
3. « Plus d'options » expander: photo, categories, notes.
4. CTA pinned at the bottom, enabled as soon as name + day/month are valid; keyboard « done » saves;
   success → close + `lightImpact` + snackbar « Léa ajoutée » (with « Annuler » if cheap).
- Bulk path: **import from contacts** is the fastest value — surface it in the empty state and
  onboarding, not only in settings. Show a preview list with checkboxes (pre-checked) before import.
- Stretch: natural-language single field « Léa 12 mars » (Todoist) parsed in the Notifier.
- Avoid: photo picker as the first thing in the form, required fields that aren't needed to
  remind, validation only after pressing save, a date sheet whose confirm button says « Ajouter ».

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

- Inline search that filters live (current) — keep it, but the whole 48 dp field must be tappable,
  show a clear button with a tooltip, highlight matched text in results.
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
- Avoid: grids that start on the 1st regardless of weekday (current bug), color-only markers.

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

- **Value first, account later** (Duolingo lazy sign-up): « Continuer sans compte » stays prominent;
  ask to save the account at a moment of value (after 3 birthdays added, or before reinstall risk),
  never as a wall.
- Order of sign-in options: Google (one tap) › Email › Guest. Biometric unlock prompt
  automatically when enabled (already done).
- Intro motion ≤ 600 ms, CTAs usable immediately; layout must scroll on small screens (current
  auth screen overflows at 360×640).
- **Permission priming** (Duolingo, Instagram): before the system prompt, a sheet explains the
  benefit in one line (« Pour vous prévenir 7 jours avant et le jour J ») with « Autoriser » /
  « Plus tard ». Ask in context (notifications after the first birthday is added; contacts when the
  user taps import). If denied: explain how to enable, link to settings, never nag twice a week.

## I. Reminders & retention — ethical hooks

People come back when AnKi saves them from forgetting and makes them look thoughtful.
- Notification copy is personal and actionable: « Demain, Léa fête ses 30 ans 🎂 » with actions
  « Souhaiter » (opens share/SMS/WhatsApp with a prefilled message) and « Idée cadeau ».
- Cadence: J-7 + J-0 (current) + optional J-1; per-person mute; quiet hours.
- Weekly digest (opt-in) « Cette semaine : 2 anniversaires » — Monday morning.
- Close the loop: « Marquer comme souhaité » → mint check, small celebration (peak-end rule).
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

On J-0 the hero switches to **celebration** (S1 celebration gradient + S4 petals once) with one
primary CTA « Souhaiter » and a secondary « Idée cadeau ». After the wish: « Marqué comme
souhaité » (mint) — the day ends on a high note (peak-end rule). Several birthdays today →
carousel, each with its own state.

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
