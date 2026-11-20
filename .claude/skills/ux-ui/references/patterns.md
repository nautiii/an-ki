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
- F. Calendar (removed)
- G. Empty, loading, error, offline states
- H. Onboarding, auth, permissions
- I. Reminders & retention (ethical)
- J. Settings
- K. Gift ideas / scanner
- L. The birthday moment (celebration)
- M. 2025–2026 trends — adopt, adapt or skip
- N. UX laws cheat sheet
- O. Friction budgets — the three jobs, step by step

---

## A. Structure

**Navigation** — floating glass pill (identity S5) with ≤ 4 destinations, icon + label.
- Labels: with 2–3 destinations show both labels (clearer, and TalkBack needs them); the
  "selected-only label" style is acceptable only if every item keeps a semantic label + tooltip.
- Refs: Spotify / Instagram bottom tabs; iOS 26 floating tab bar; M3 `NavigationBar`.
- Flutter: custom pill today; `NavigationBar` + `NavigationDestinationLabelBehavior` if it's
  ever rebuilt; `Semantics(selected: …)` on items.
- Keep it stable: a destination never moves or turns into an action. Spotify added a « Créer »
  button to its bottom bar in 2024, beside « Bibliothèque », and had to let users hide it in July
  2025; Netflix's 2025 TV redesign cut friction but moved familiar browsing and drew a backlash.
  A creation action is a floating button beside the pill, never a tab (§C).

**Choose the container** (Material + Apple HIG agree):

| Need | Pattern | AnKi examples |
|------|---------|---------------|
| Quick create/edit, ≤ ~6 fields, keep context | Modal bottom sheet (drag handle, `useSafeArea`, CTA pinned above keyboard) | Add/edit birthday, day details |
| Rich content, deep linkable, long forms, multi-step | Full page with large title (`SliverAppBar.large`) | Person page (`/person/:id`), settings |
| Blocking decision, irreversible | Dialog (title = question with object, destructive button named by action) | Delete account, sign out as guest |
| Transient feedback, undo | Floating `SnackBar` + `SnackBarAction` | Deleted · Annuler, Saved |
| Persistent state needing action | `MaterialBanner` / inline card | Notifications disabled, sync pending |
| Contextual secondary actions | `MenuAnchor` (long-press / ⋯) | Share, duplicate, mark as wished |

Avoid: forms in dialogs, sheets stacked on sheets, full-screen spinners, new routes for one field.

## B. Home — "who's next"

The home answers one question in < 2 s: *who, when, how old*. Pattern = **hero + time-bucketed
agenda** (Netflix billboard + Todoist Upcoming / Google Calendar schedule).
- **Hero** (S1): next birthday(s); several on the same day → stacked cards, each with its own
  state (§L, `next_birthday.dart`); before the day: avatar, « Demain / Dans N jours », name, date,
  the coming age in its orbit (S3); on the day: small avatar and « Aujourd'hui », name, « fête ses
  N ans aujourd'hui », the age in big numerals, « Souhaiter » + « Déjà souhaité » (§L), which
  give way to « ✓ Souhaité » in the sentence once wished (the card tightens, no lone pill band);
  « Idée cadeau » in the week before with B4.
- **Agenda list** grouped by time: « Dans les 7 jours », then one section per month
  (« Novembre », « Janvier 2027 ») — chunking (Miller) that holds for a whole year, where
  « Plus tard » would become a flat list again. Sticky section headers. Each row: avatar ringed
  with the person's category tones, name on one line, « 9 octobre · 34 ans » on one line, the days
  left in their orbit (S3): every row the same height, whatever the name. The birth year is
  noise here.
- Greeting personalised by time of day (Spotify « Bonsoir ») is a cheap warm touch; keep it short.
- Refs: Todoist *Upcoming*, Apple Reminders *Today/Scheduled*, Google Calendar *Schedule*,
  Facebook birthdays (today first + quick wish).
- Flutter: `CustomScrollView` + `SliverMainAxisGroup` per section with a pinned
  `SliverPersistentHeader`; grouping in a domain rule (`agenda()`) wired by `agendaProvider`.
  Shipped in step 2: `home_screen.dart`, `agenda_list.dart`, `agenda_tile.dart`.
- Avoid: one flat list sorted by name, the birth year as main metadata, more than one hero.
- Beyond the screen (friction review 2026-11-14): the answer to « who's next » that costs zero
  taps is a **home-screen widget** (P1: « Hugo · dans 3 jours · 34 ans », on J-0 « Léa · 29 ans ·
  Souhaiter »); it needs `home_widget` and native Glance code, so it comes with its own brief.
  The one-tap answer starts without a break: native splash and startup screen in the same plum
  night, then the cached agenda (P2, ux D28), cold start measured on the emulator.

## C. Capture a birthday (core flow — make it < 10 s)

**Decided 2026-11-15, in design (friction review P7 + P8)**: the « + » leaves the top-right
corner, the hardest reach one-handed, for a floating button beside the nav pill (alone when the
pill is hidden), tonal (`primaryContainer`) so that the J-0 « Souhaiter » stays the screen's one
filled action (identity §3.3); and adding becomes **one line** — « Léa 12 mars », « Mamie 3/2/50 » — parsed live
by a domain rule (name + day/month, optional year, month names in FR and EN, the phone region's
numeric order), Enter adds, pasted lines add in bulk, « Ajouter et continuer » keeps the sheet
open. The two-field sheet below stays for **editing**. Refs: Todoist Quick Add, Google Calendar
quick event; Google's FAB on Contacts, Calendar and Gmail. Update this section once it ships.

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
   Groups on one scrolling row of `FilterChip`s (`group_picker.dart`): Famille, Amis, Travail,
   the user's own by name, Autres; icon in the group tone, replaced by the check once selected.
   « Nouveau groupe » last opens the creation right below the row, never a sheet on a sheet:
   the name, the tone dots (the first free one already picked), « Créer » disabled while the
   name is empty or already a group's; the new group arrives ticked (shipped 2026-10-24).
4. CTA enabled as soon as name + day/month are valid; keyboard « OK » saves; `lightImpact` on
   save. Editing reuses the sheet, prefilled (« 15/10 » for a yearless birthday).
- Without a year no age is shown anywhere (agenda line, hero, person page): never an
  invented one.
- Bulk path: **import from contacts** is the fastest value. Shipped in step 5.2: the empty home
  is the invite (« Choisir dans mes contacts » first, a line on what AnKi reads), and
  `contact_import_screen.dart` (also opened from Settings) asks for access on arrival, then lists
  the contacts pre-checked, soonest first, with those already in AnKi apart and not importable
  (`previewContactImport`: same name up to case, accents and dashes, same day). Denied →
  « Autoriser l'accès »; blocked → « Ouvrir les réglages », re-read on return.
- Next for the bulk path: a discreet suggestion when a phone contact gains a birthday (« 2
  nouveaux anniversaires dans vos contacts · Ajouter », P9, only once access is granted; Google
  Photos' suggestions). Watch Android 17's contact picker: it shares only the chosen contacts,
  without `READ_CONTACTS`, and Google Play will ask apps targeting Android 17 that still request
  the permission to justify why the picker isn't enough. The pre-checked bulk import justifies
  it; a single « Ajouter depuis un contact » could use the picker (check that a birthday is among
  the data it can return).
- Avoid: photo picker as the first thing in the form, required fields that aren't needed to
  remind, validation only after pressing save, a date control that forces the year.

## D. Edit, delete, quick actions

- Tap a person (row, hero, belated card, day sheet) → their page (view first: countdown, age,
  groups, wish, reminders, wish history); « Modifier » there opens the edit sheet. Long-press → `MenuAnchor` with contextual actions.
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
  clear button and its tooltip; the matched letters are highlighted in the results.
- Filters: horizontal `FilterChip` row (Airbnb, Google Photos, Spotify home chips) — selected state
  shows a checkmark or filled tone, not color alone; a « Tout » chip resets. Multi-select AND/OR
  semantics must be obvious (« Famille + Amis » = union). Shown only once two groups are carried
  by the birthdays (`groupFilters`): a single one would sort nobody out.
- No results → « Aucun résultat pour « Lé » » + CTA « Ajouter « Lé » » prefilled (Notion/Linear
  create-from-search): zero dead ends.
- If the list grows (100+), upgrade to `SearchAnchor` with recent searches.

## F. Calendar (removed)

The month grid and its Agenda | Calendrier switch were removed on 2026-11-10: the home keeps
only the agenda by month (§B), which already answers "who's next" and reads a whole year.
Don't bring a month grid back without a user job it serves better than the agenda.

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
  on the welcome (`welcome_screen.dart`) — one promise on the lotus hero (S1), « Commencer » opens an
  anonymous session at once, « J'ai déjà un compte » pushes the sign-in above it. Saving the
  account comes at a moment of value, never as a wall — shipped in step 5.4: from 3 birthdays a
  guest finds `GuestBackupCard` (`features/settings/widgets`, through the home's `guestBackup`
  slot) after the agenda's last month; « Sauvegarder avec Google » links the anonymous account
  (same uid, same data), then the profile takes the Google names. A Google account AnKi already
  knows (B5.5, 2026-11-05): the card offers « Ouvrir ce compte avec mes 12 anniversaires »
  (full width, the label wraps at 200 %) and « Choisir un autre compte » below; opening moves
  the guest's data into that account without duplicates, then « 9 anniversaires ajoutés à ce
  compte · 3 y étaient déjà ». Its address is an e-mail account's: only « Choisir un autre
  compte ». Other failures show under its text, a closed picker says nothing.
- The sign-in (`auth_choice_screen.dart`, « Bon retour ») offers Google (one tap) › e-mail ›
  sign-up; no guest there. Locked by the fingerprint, it stands alone, prompts at once and puts
  « Déverrouiller » first so a dismissed prompt can be retried.
- The e-mail forms (`login_screen.dart`, `signup_screen.dart`) share `widgets/auth_form.dart`:
  themed fields in an `AutofillGroup`, `PasswordField` with a labelled eye, a submit enabled by
  the draft (`SignInDraft`, `SignUpDraft`) that keeps its label while waiting. « Suivant » goes to
  the next field, never to an eye. The sign-up asks the password once: the eye shows it and the
  reset link catches a typo (2026-10-25). « Mot de passe oublié ? » sends Firebase's reset link to the typed address,
  in the app's language (`PasswordReset`, its own controller): without an address the field
  says what is missing; sent, « E-mail envoyé à … » stays in the form with « Renvoyer le
  lien », worded neutrally since Firebase hides whether the address has an account (shipped
  2026-10-24).
- No intro motion: the CTAs are there from the first frame; layouts scroll on small screens.
- **Permission priming** (Duolingo, Instagram), shipped in step 5.3: never a system prompt at
  launch — since Android 13 notifications are off until allowed, and the median Android opt-in
  fell to about 53 % in 2025 (Airship benchmarks). `ReminderPrompt` (`app/bootstrap`) opens `ReminderOfferSheet` over the agenda at a
  moment of value — an import, the first birthdays added by hand, a sign-in that brings an agenda
  to this phone — at most once per session: what just happened (« 12 anniversaires ajoutés »),
  the cadence from the reminder preferences, the next real J-0 reminder as the notification will show it,
  « Activer les rappels » / « Plus tard ». A refusal is respected (the sheet closes); blocked
  (two refusals on Android, one on iOS), the sheet and Settings › Rappels lead to the app's
  notification settings. Contacts are asked when the user taps import, with the same denied /
  blocked states.
- **Reminders off, day after day** (shipped 2026-10-24): while the agenda has someone and the
  notifications are refused or blocked, a calm card above the hero (`RemindersOffCard`, given to
  the home's `notice` slot by `app/router`) says « Rappels désactivés » with « Activer », or
  « Réglages » once blocked; its cross hides it for good on this phone (`DeviceSettings`) and
  says Settings › Rappels stays the way back. A state, never a dialog or a relaunch.

## I. Reminders & retention — ethical hooks

People come back when AnKi saves them from forgetting and makes them look thoughtful.
- Notification copy is personal and actionable: « Demain, Léa fête son anniversaire. » (B6; the
  age comes with backlog B8). The J-0
  notification carries « Souhaiter » (shipped in step 4, Android: `AndroidNotificationAction`
  with the birthday id as payload; `app/bootstrap` goes home and opens the share sheet).
  « Idée cadeau » on J-7 comes with B4.
- No age in a repeating notification: reminders repeat yearly (`DateTimeComponents.dateAndTime`)
  with the text written when scheduled, so an age goes stale if the app isn't reopened for a year.
  Today's texts carry none. A one-shot plus a yearly ageless fallback fires twice on Android (the
  plugin drops the year): backlog B8 brings the age back with a rolling window of one-shots,
  replanned daily in the background; `ReminderNotification.age` is still computed for that.
- Cadence (B6, shipped): J-7 + J-0 by default, J-30 and J-1 on request, one time of day; per
  person: as usual, none, or custom. No quiet hours: the chosen time replaces them.
- Weekly digest (opt-in) « Cette semaine : 2 anniversaires » — Monday morning.
- Close the loop: « Souhaité » → mint check, light haptic, « Annuler » (peak-end rule; §L).
- Yearly recap (Spotify Wrapped spirit) « Votre année en anniversaires » — shareable, delightful.
- Home-screen widget for the next birthday (P1, §B): table stakes in the category (CandlesUp,
  hbd, Birthday Reminder Widget all ship one), and a widget case study on Android Developers
  reported +25 % retention; build it to Google's widget quality tiers (2025: system corner
  radius, generated previews, sized touch targets).
- App shortcuts on a long-press of the icon (P3): « Ajouter un anniversaire », « Rechercher »,
  and on J-0 a dynamic « Souhaiter à Léa » — the screen nobody has to open (needs
  `quick_actions`, its own brief with P1).
- Forbidden: guilt copy (« Vous avez oublié… »), fake urgency, streak pressure, re-engagement
  spam, hiding account deletion.

## J. Settings

Shipped on 2026-10-24 (`settings_screen.dart`, `features/settings/widgets/`): titled sections in
rounded containers (`SettingsSection`, titles announced as headers), instant apply, the account
last (iOS Settings, recent Android settings with grouped rounded containers):
1. **Profil** — the pseudo edited in place (`PseudoField`): « OK » or the check saves it, no
   separate button; emptied, it clears and the home greets by first name.
2. **Préférences** — Thème Système / Clair / Sombre (default Système: `themeMode` in the profile,
   an old `isDark` reads as Clair or Sombre) and Langue Français / English, each language named in
   itself: `SegmentedButton`s without icons, stacked when a label no longer fits on one line
   (200 % text, small screens) rather than cut.
3. **Anniversaires** — Rappels (`RemindersTile`: the state on this phone, and « Activer les
   rappels » or « Ouvrir les réglages » when off; then « Me prévenir » and « Heure des rappels », B6), Importer les
   contacts; Exporter later.
4. **Sécurité** — only when the phone has a fingerprint (`fingerprintAvailableProvider`, read
   again at each visit): Connexion biométrique.
5. **Compte** — Se déconnecter, Supprimer mon compte (the only row in the error color; a dialog
   names the consequence).
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
  (`share_plus`) with the first suggested wish (below), editable in the app chosen.
  Once an app is chosen the birthday is marked wished — Android reports the app chosen, not the
  sending, hence « Annuler ». A sheet closed without a choice changes nothing.
- « Déjà souhaité » (text button) marks it at once, for a call or a wish in person.
- Then the mint « ✓ Souhaité » pill takes the buttons' place, at their height: the card doesn't
  jump. Snackbar « Anniversaire de Léa souhaité · Annuler » (`lightImpact`).
- Several birthdays today → stacked cards, each with its own state. The person's identity stays
  one button (opens the sheet); the actions are separate targets for TalkBack.
- Model: `wishedYears` (`arrayUnion` / `arrayRemove`), rule `BirthdayWishes.isWished(today)` —
  the year of the latest birthday, so a belated wish on 1 January counts for 31 December.
- **Suggested wishes** (P4, shipped 2026-11-20: `domain/wish_suggestions.dart`,
  `widgets/wish_text.dart`, `widgets/wish_bubble.dart`). Gmail Smart Reply: the first position
  takes 45 % of the picks, diverse suggestions get 7.5 % more clicks.
  - The rule is a pure domain function, local ICU templates, no AI or network. Three messages:
    the person's saved message first; then the milestone age (1, 18, every ten years; never an
    age without a birth year), else a short one; then a warm and a light one. The group sets the
    tone — Travail: two sober warm ones, no tu nor vous, the light one dropped. Gender-neutral,
    one emoji at most.
  - The variant is a stable hash of id + year: the same all day, another next year.
  - On the J-0 hero and the person page the first message sits whole in a bubble above
    « Souhaiter » (16 % `onCelebration` veil on the hero, cloud `tertiaryContainer` on the
    page), so the common case stays 1 tap and shows what it sends. Tapping the bubble opens
    « Autres messages »: the three as `primaryContainer` cards, one tap each shares it, and
    « Écrire un message pour Léa » at the bottom. Rejected: tone chips on one bubble (2 taps to
    read the three, white on white on the gradient); three bubbles (hero 197 → 479 dp, off
    screen at 200 %).
  - The person page's « Message » section shows the saved message or the suggested one, and
    hides on J-0 while the bubble is there.
- **Belated wish** (P6, reduced by the maintainer on 2026-11-20 to the message and the age): the
  « Hier » card (`belated_wish.dart`) keeps its shape and adds « a eu 34 ans » under the name
  (never « 0 », never without a year); its message is belated (« Un peu en retard, mais joyeux
  anniversaire Hugo ! 🎉 »), never guilt — no « Désolé » (ux D15, Facebook).
- Next, own brief: a link to the person's contact, opted in person by person — « Appeler »,
  « Message » opening the conversation with the text ready (Google Contacts' action row): two
  taps from the J-0 notification to a sent wish, but it touches the promise « AnKi ne lit que les
  noms et les dates » (P5).
- Later: « Idée cadeau » (B4, deferred by the maintainer).

## M. 2025–2026 trends — adopt, adapt or skip

| Trend | Verdict for AnKi |
|-------|------------------|
| **Material 3 Expressive** (springs, shape contrast, emphasized type, floating toolbars + FAB, button groups, FAB menu) | **Adapt the principles** with core Flutter: springs for drag/dismiss, bolder type for the key number, squircle/shape contrast, a prominent primary action. Google's research behind it (46 studies, 18 000+ participants) found key elements spotted up to 4× faster when made bigger and more prominent, and older users as fast as younger ones. Flutter core is not implementing M3E; community packages (`material_3_expressive`, `m3e_core`) exist — never add one without the maintainer's approval. |
| **Liquid Glass** (iOS 26 translucent floating chrome) | Already echoed by the nav pill. Glass stays limited to floating chrome. |
| Edge-to-edge (enforced from Android 15) & predictive back | Adopt: `SafeArea` everywhere, transparent system bars with correct icon brightness per theme; Flutter's default Android transition (3.44+) is `PredictiveBackPageTransitionsBuilder`, and `android:enableOnBackInvokedCallback="true"` in the manifest gives the gesture preview (adopted 2026-10-24). |
| Skeletons, optimistic UI, micro-interactions + haptics | Adopt (G, identity §8–9). |
| Natural-language / AI-assisted input | Adapt later: « Léa 12 mars » quick add (C). No chatbot. |
| Bento-grid dashboards | Skip for the home (agenda beats tiles for time); possible for a yearly recap. |
| Dynamic color (wallpaper) | Skip: the lotus palette is the brand. |
| Home-screen widgets (Google's widget quality tiers, 2025) | Adopt with its own brief (P1): zero taps to « who's next ». |
| Privacy pickers (photo picker; Android 17 contact picker) | Adopt where they remove a permission without adding steps; keep `READ_CONTACTS` for the pre-checked bulk import, with its Play declaration (§C). |
| Smart suggestions (Gmail Smart Reply) | Adapt as local templates for wishes (P4): no AI service, no network. |
| Vertical feeds (Spotify 2022, TikTok) | Skip: a year of dates reads better as an agenda. |
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
- **Goal-gradient** — show progress toward the end of a multi-step flow (« 3 sur 5 »), or remove
  the steps.

## O. Friction budgets — the three jobs, step by step

From the friction review of 2026-11-14 (ux-backlog). A budget is the most a job may cost on its
common path; every brief that touches a job counts its steps before and after against it.

| Job | Budget (common path) | Measured 2026-11-14 | Levers |
|-----|----------------------|---------------------|--------|
| See who's next | 0 taps (widget), else 1 tap and < 1.5 s to the agenda | 1 tap; cold start never measured; a light flash in dark (D28) | widget (P1), one plum night from splash to agenda (P2), cached agenda |
| Wish | 1 tap from the hero or the J-0 notification to a messaging app with a fitting message ready | 3–5 taps: share sheet → app → find the person → send; one message for everyone. 2026-11-20 (P4): 1 tap with a fitting message shown before sending; another message 2 taps without typing (was 4 and typing); the steps outside AnKi unchanged | contact link (P5) |
| Capture one | 1 tap + 1 line + Enter, ≤ 5 s, one-handed | 3 taps + 2 fields, « + » in the top-right corner | thumb-zone button (P7), one-line add (P8), app shortcut (P3) |
| Capture many | ≤ 4 taps from the empty home to a full agenda | 4 taps: import, allow, import, reminders | contact suggestions (P9) |
| Undo a mistake | 1 tap, never a confirmation | undo on delete and wish | keep |

Rules:
- A step that only confirms is a step to remove: undo instead.
- What the app can infer (a date's order, a name's split, a message, a group) is inferred and
  shown, never asked.
- The screen nobody opens beats the fastest screen: notification actions, widget, app shortcuts.
- Count taps, fields, decisions and waits; time the flow on the emulator when speed is the claim
  (Doherty: answer within 400 ms).
