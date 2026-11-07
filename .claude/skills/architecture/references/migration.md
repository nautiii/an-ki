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

None open. Record new debt as a row:

| # | Debt | Evidence | Consequence | Step |
|---|------|----------|-------------|------|

UX debt (contrast, 200 % text, labels, raw colors, dates without `DateFormat`) is tracked in the
ux-ui backlog (`ux-backlog.md`), not here.

## 3. Remaining steps

Recommended order: M10 only on a concrete need. Sizes: S < 1 h, M ≈ half a day, L ≈ a day (agent + review).

### M10 — Per-user collections · L · system change, only on a concrete need
- Left out of M8: move `birthday`/`books` to `user/{uid}/…` — data migration with dual read,
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
