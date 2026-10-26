# Remaining work — device checks, open debt, structural steps

The code follows the target since steps M0–M9 (2026-10-08/11; the commits of those days hold the
details). This file lists only what remains. Keep it short: delete a line once it's done, record
what you discover.

## Contents
1. Not verified outside the tests yet
2. Open debt
3. Remaining steps
4. How to run a step

---

## 1. Not verified outside the tests yet

Delete each line once done:
- `firestore.rules` deployed by the maintainer (owner pinned on update, M0; private groups):
  firebase skill, `references/console.md` §1 — tests in the emulator and a server compilation
  passed on 2026-10-25.
- M2–M6 and M9 on the emulator (device skill), all behind the maintainer: sign-in (email and
  sign-up land on the app, not on the form; Google, where a cancel stays silent; anonymous), a
  restored session locked behind the fingerprint without the app flashing first, unlock, a
  revoked fingerprint (`biometricToken` changed in the console) signing out with « La connexion
  biométrique n'est plus valide… », sign-out with the fingerprint on (lock only) and off,
  enabling and disabling the fingerprint in the settings (the switch shows only once a screen
  lock and a finger are enrolled, device recipes §9), birthday with a photo (kept when editing
  without a new one; the gallery, no camera needed), account deletion with the fingerprint on or
  off (birthdays, books and profile gone, no error) on a test account, birthdays tab shown again
  after signing back in.
- Private groups (UX piste C, 2026-10-24), once the maintainer has deployed `firestore.rules`
  (until then the server refuses the writes and the new group vanishes): a group created in the
  birthday form lands in `user/{uid}/categories` and arrives ticked, offline too; account
  deletion erases those groups.
- Settings in sections and the Système / Clair / Sombre theme (UX piste B, 2026-10-24): an older
  profile keeps its light or dark choice, Système follows the phone's dark mode live, the
  security section shows only with an enrolled finger.
- The reminders-off card (UX Q8, 2026-10-24): above the hero once notifications are refused
  (`perm reset`, then « Ne pas autoriser »), « Activer » reopening the system box, « Réglages »
  once blocked and the card gone on the way back, the cross keeping it hidden after a restart
  (stored with `flutter_secure_storage`).
- The forgotten password link (UX Q9, 2026-10-24): the Firebase reset e-mail reaching a real
  inbox in the app's language (French and English templates in the console), its link
  setting a new password, and the confirmation shown for an unknown address too.
- Guest backup (UX step 5.4), behind a guest session the maintainer opens with 3 birthdays or
  more, and the debug SHA-1 in Firebase: the card after the agenda, the Google picker, the link
  (card gone, « Vos N anniversaires sont sauvegardés », the greeting with the Google first name),
  a Google account already used by AnKi explained in the card, a retry offering every account
  again. Checked on 2026-10-19: a saved account sees no card.

Checked on the emulator on 2026-10-18 and removed from the list: reminders (120 planned for 60
birthdays, J-0 and J-7 all at 10:00, no duplicate id, AlarmManager holding the same 120; a J-0
and a J-7 fired once each, the J-7 on the DST change), contacts import refused, a tab keeping
its scroll, settings above the tab and back, back from the e-mail sign-in, system back leaving
the app. The search is now its own screen (`birthday_search_screen.dart`) that hides the tabs,
so « keeps its search » no longer applies.

## 2. Open debt

| # | Debt | Evidence | Consequence | Step |
|---|------|----------|-------------|------|
| A15 | Book lookup failures flattened | `BookRepository.fetchBookByIsbn` returns `null` for every failure but the quota (HTTP error, network, parsing), as for an unknown ISBN; a volume without title gets `'Unknown Title'`, an English UI string in the data layer | offline, a scan reads « Livre non trouvé »; untranslatable text | local fix: `BookFailure.network`, empty title worded by the UI |
| A16 | Older groups still shared | groups created before 2026-10-24 sit in the top-level `category` collection, readable by any signed-in user, and `sharedCategoriesProvider` downloads every user's | their names leak to any account through the API; the stream grows with the user base | system: copy each into its owner's `user/{uid}/categories` (same id, so birthdays keep pointing at it), then restrict `category` reads to the predefined ones — data migration, brief and approval; plan in the firebase skill, `references/migrations.md` §5 |
| A17 | Account deletion erases first | `SettingsScreen` runs `AccountDeletion.eraseData()` (birthdays, books, groups, profile), then `AuthController.deleteAccount()`; Firebase refuses to delete an account signed in a while ago (`requires-recent-login`, mapped to `unknown`) | the data is gone, the account stays, the user reads « Le compte n'a pas pu être supprimé » (found with D23, 2026-10-24) | structural: re-authenticate first (Google, or the password), or delete the account before its data — brief |
| A18 | Group removal follows the live account | `group_removal.dart` (8472914) commits the deletion when the undo snackbar closes, against the account signed in at that moment; reviewer pass of 2026-10-26 | switching account inside the undo window removes the group from the wrong account; no test covers a failed removal | local fix: capture the uid when the removal starts, test the failure path; same review flagged French typography and agreement in the new ARB strings |

UX debt (contrast, 200 % text, labels, raw colors, dates without `DateFormat`) is tracked in the
ux-ui backlog (`ux-backlog.md`), not here.

## 3. Remaining steps

Recommended order: M10 only on a concrete need. A local fix (A15) goes with any change
touching its files. Sizes: S < 1 h, M ≈ half a day, L ≈ a day (agent + review).

### With B4 — a notification tap opens the person page · S
- Taps already reach the app: `NotificationService` streams them (cold start included) and
  `app/bootstrap/app_initializer.dart` handles « Souhaiter » (payload = birthday id). A tap on
  the notification itself only opens the app: once the person page exists, `go` there, behind
  the access redirects.

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
4. Run `dart format`, `flutter analyze`, `dart analyze` (runs `riverpod_lint`), the touched
   features' tests, then the whole suite (`test/architecture/` included).
5. After changing providers or shared test fakes, re-run the ux-ui snapshot script: the analyzer
   skips `.claude/` and the script only compiles once copied, so only a run proves it still works
   (steps in its header).
6. Update this file: the finished step and the cleared debt deleted, discoveries added to §2;
   general gotchas go to `patterns.md` §15.
7. Commit per the git-workflow skill: one intent per commit, `git add <paths> && git commit`.
