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
