# Remaining work — device checks, open debt, structural steps

The code follows the target since steps M0–M9 (2026-10-08/11; the commits of those days hold the
details). This file lists only what remains. Keep it short: delete a line once it's done, record
what you discover.

## Contents
1. Not verified outside the tests
2. Open debt
3. Remaining steps
4. How to run a step

---

## 1. Not verified outside the tests

Delete each line once done:
- Modules the user turns on (B9 step 4, 2026-11-09), on the maintainer's phone with their real
  account: an existing profile (no `modules` field) opens on Anniversaires alone, no bar, its
  reminders still scheduled; Réglages › Modules turns Livres on (the bar and the « Livres » tab
  appear, the old scanned books show) and off; the choice follows to a second device signed in
  to the same account; a guest who turned Livres on and opens an existing Google account
  (B5.5) finds Livres on there; « Effacer les données Livres… » on a test account only, once
  online (`books` gone in the console) and once in airplane mode (refused, nothing erased).
- Livres step 9, next volume release (2026-11-11, branch `claude/books-release-c62e6a`), once
  the step 6 rules are deployed (before, every check's write is refused, silently on opening,
  with a snackbar after a pull). On the phone, online: open Livres with a series whose next
  volume has a BnF record (« Tome N paru · vous ne l'avez pas », « selon la BnF · vérifié le
  … ») and one without (« date inconnue », « rien à la BnF · vérifié le … »); pull down on a
  series; « Ajouter la date » (a day, then « Je ne connais que le mois »), « Modifier la date »,
  « Effacer la date »; airplane mode: a pull says « Pas de connexion… », the shelf opens without
  any message. Google Books: a series whose next volume Google dates ahead of the BnF (One
  Piece 114, Sakamoto Days 24 at the time of writing) reads « Tome N · sortie le … », « selon
  Google Books · vérifié le … ».
- Livres step 8, burst scanning and corrections (2026-11-11, branch `claude/books-burst-21d5db`),
  once the step 6 rules are deployed. Seen on the emulator with the rules refused: the scanner
  page, « Saisir un ISBN » and its inline error, a typed ISBN stacking as « ISBN … · infos à
  compléter » (online and in airplane mode), the « Ajouter une série » sheet and its range
  error, « Terminé », dark and 200 %. **Never seen: a real barcode** (the emulator's camera
  can't present one). On the phone: scan five volumes in a row without closing the page (one
  light vibration and one row each, newest first: « ✓ One Piece · tome 108 »); hold a book in
  front of the camera (one row only); scan an owned volume (« Déjà dans votre collection ·
  One Piece 107 », no vibration, one notice even for a pile); the torch; a row opens its sheet,
  « Introuvable · Classer » the classification. Airplane mode: scan two volumes (« infos à
  compléter »), back online, open Livres → they are completed (series and number) or « à
  classer », nothing marked « introuvable ». « Ajouter une série à la main » from the empty
  shelf and the app bar: « One Piece », « 1-12, 15 », « Série terminée » → the series page with
  13 volumes, holes 13 and 14, complete; the same name again joins it. Corrections on a real
  shelf: move and renumber a volume, remove with « Annuler » (also from the burst, then rescan),
  rename, merge with « Annuler », mark complete, delete with « Annuler ». Not observed on the
  emulator: the « Déjà dans votre collection » notice (2 s, maybe missed by the screenshot) and
  any write-refused snackbar.
- Livres step 7, shelf and series pages (2026-11-10, branch `claude/books-shelf-c8be56`), once
  the step 6 rules are deployed (before, every read of the shelf is refused and the tab shows
  « Étagère indisponible »): on the phone, Livres on, an account with legacy `books` → the
  shelf lists their series A to Z (cover, else initials; the last volume in big digits;
  « Prochain : tome N · date inconnue »; « Il vous manque … » where volumes are missing) and
  « À classer (n) » for the volumes without a series; search « pi » finds One Piece; a series
  page (header, « Prochain » card, holes as chips, grid: owned filled, missing outlined; a tap on
  an owned number opens its sheet); rename, merge, mark complete, delete (each « Annuler »
  restores; without it the console shows the write after ~5 s); a volume's sheet → « Changer
  de série ou de numéro » moves it, « Retirer de la collection » with « Annuler »; the inbox
  classifies a volume into a new series. A real scan from `/books/scan` (« Ajouter » → the
  volume on the shelf), the camera refused then granted from « Ouvrir les réglages ». Airplane
  mode: the shelf still reads from the cache and the « Hors ligne · dates non actualisées »
  banner appears after ~3 s. TalkBack on a row reads « One Piece, dernier tome 108, … ».
- Livres step 6, series and volumes in Firestore (2026-11-09, branch
  `claude/books-firestore-ce51f6`). **The `bookSeries` and `bookVolumes` rules are proved in the
  emulator but not deployed**: deploy them (firebase Workflow D) once the chain is on `main`,
  before installing an APK built from it, else every scan and the legacy import are refused.
  Then, on the phone (the emulator's camera can't present a barcode): scan a known manga (« One
  Piece », a recent volume) → the sheet, « Ajouter », the volume in the carousel with its cover;
  in the console `user/{uid}/bookVolumes/{isbn}` with `seriesId`, `number`, `lookup: found`, and
  its `bookSeries` document; a second volume of the same series joins it. Scan in airplane mode
  → « Pas de connexion… » and nothing written (the old sheet still needs a lookup first). An
  account with legacy `books`: open the Livres tab once online → its volumes appear, each legacy
  document carries `importedAt`, reopening imports nothing more; deleting a volume and reopening
  doesn't bring it back. Account deletion erases `bookSeries`, `bookVolumes` and legacy `books`;
  a guest with volumes moving to a Google account that already has a series of the same name
  ends with one series.
- B5.5 (2026-11-05; rules of c626403 deployed the same day), behind the maintainer on a test
  Google account that already has AnKi data: a guest with ≥ 3 birthdays (one shared with the
  account) taps « Sauvegarder avec Google », picks that account, then « Ouvrir ce compte avec
  mes N anniversaires »: no second picker (else note it), the account's agenda gains the others
  once, « … ajoutés à ce compte · 1 y était déjà »; in the console no `transferTo` left, no
  `user/{guestUid}` nor its `categories`. Offline before the tap: « Pas de connexion… », still a
  guest. A Google address whose `email_verified` is false (non-Gmail Workspace?) would be refused
  by the rules: check one if you can.
- Private groups and the rules deployed on 2026-11-04 (pinned owner, older shared groups no longer readable), on a device: the four
  predefined groups and the copied private groups shown and ticked on their birthdays, a group
  created in the birthday form lands in `user/{uid}/categories`; account deletion checks (identity confirmed first, a66f754).
- M2–M6 and M9 on the emulator (`device-runner`), all behind the maintainer: sign-in (email and
  sign-up land on the app, not on the form; Google, where a cancel stays silent; anonymous), a
  restored session locked behind the fingerprint without the app flashing first, unlock, a
  revoked fingerprint (`biometricToken` changed in the console) signing out with « La connexion
  biométrique n'est plus valide… », sign-out with the fingerprint on (lock only) and off,
  enabling and disabling the fingerprint in the settings (the switch shows only once a screen
  lock and a finger are enrolled, device recipes §9), birthday with a photo (kept when editing
  without a new one; the gallery, no camera needed), account deletion with the fingerprint on or
  off (identity confirmed first: password in the dialog, the Google picker, nothing for a guest;
  birthdays, books and profile gone, no `user/{uid}` left behind, no error) on a test account, birthdays tab shown again
  after signing back in.
- Settings in sections and the Système / Clair / Sombre theme (UX piste B, 2026-10-24): an older
  profile keeps its light or dark choice, Système follows the phone's dark mode live, the
  security section shows only with an enrolled finger.
- The reminders-off card (2026-10-24): above the hero once notifications are refused
  (`perm reset`, then « Ne pas autoriser »), « Activer » reopening the system box, « Réglages »
  once blocked and the card gone on the way back, the cross keeping it hidden after a restart
  (stored with `flutter_secure_storage`).
- The forgotten password link (2026-10-24): the Firebase reset e-mail reaching a real
  inbox in the app's language (French and English templates in the console), its link
  setting a new password, and the confirmation shown for an unknown address too.
- Guest backup, behind a guest session the maintainer opens with 3 birthdays or
  more, and the debug SHA-1 in Firebase: the card after the agenda, the Google picker, the link
  (card gone, « Vos N anniversaires sont sauvegardés », the greeting with the Google first name),
  a Google account already used by AnKi explained in the card, a retry offering every account
  again. Checked on 2026-10-19: a saved account sees no card.

## 2. Open debt

Record new debt as a row:

| # | Debt | Evidence | Consequence | Step |
|---|------|----------|-------------|------|
| 1 | `settings -> birthday`, kept and declared (2026-11-08, decision D13) | the guest takeover B5.5 (`guest_merge.dart`) is birthday-centric: duplicate plan, shared groups, `transferTo` marks | `settings` knows one module; the other modules' data go through the `core` hooks | Resolve with a generic per-module transfer if Birthdays becomes optional |

UX debt (contrast, 200 % text, labels, raw colors, dates without `DateFormat`) is tracked in the
ux-ui backlog (`ux-backlog.md`), not here.

## 3. Remaining steps

Recommended order: M10 only on a concrete need; the legacy `books` cleanup once the Books module
runs on the maintainer's devices. Sizes: S < 1 h, M ≈ half a day, L ≈ a day (agent + review).

### Legacy `books` cleanup · S · after the Books module (decision D13, D8 amended 2026-11-08)
- The Books module (ux B9) imports the top-level `books` lazily at the first opening of its tab
  (marker `importedAt` on each old document) and keeps them as the way back.
- Once the maintainer's devices run it: delete the `books` rules, the composite index in
  `firestore.indexes.json`, the legacy code (repository, import, the old-collection part of the
  erasers) and, in the console, the leftover documents. Rules and index go through the firebase
  skill (emulator first, maintainer's deploy).

### M10 — Per-user collections · L · system change, only on a concrete need
- Left out of M8: move `birthday` to `user/{uid}/…` (`books` moved with the Books module, D8
  amended 2026-11-08) — data migration with dual read,
  rules update deployed by the maintainer, one release of overlap.
- Worth it only for a concrete need: sharing, rules complexity, cost. Brief and approval first;
  the plan is in the firebase skill, `references/migrations.md` §6.
- When it runs, store the birth date as `day`, `month` and an optional `year` instead of `date` +
  `yearKnown` (kept in step 3 of the UX roadmap to avoid a migration).

## 4. How to run a step

1. Re-read the step and the current code; adjust the plan before starting.
2. Lock behaviour first: add the missing tests before moving code.
3. Move with `git mv` (history follows), fix imports — the relative `../support/` imports of a
   moved test too — and keep each commit compiling; never mix a move with a behaviour change.
4. Run `bash .claude/hooks/verify-index.sh` (format, project norms, l10n,
   `dart analyze --fatal-infos`, tests, `test/architecture/` included).
5. After changing providers or shared test fakes, re-run the ux-ui snapshot script: the analyzer
   skips `.claude/` and the script only compiles once copied, so only a run proves it still works
   (steps in its header).
6. Update this file: the finished step and the cleared debt deleted, discoveries added to §2;
   general gotchas go to `patterns.md` §15.
7. Commit through the git-workflow skill, step 4 (stage in one call, commit the index in the next,
   after the checks and the reviewer): one intent per commit.
