# Migration plan — what remains between the code and the target

The 2026-10-07 audit (commit `46359f3`) and steps M0–M9 (2026-10-08/11) brought the code to
the target, except what this file lists. Keep it current: when a step lands, add a line to
*Done*, delete the debt it cleared and record what you discover.

## Contents
1. Where the code stands
2. Open debt
3. Remaining steps
4. How to run a step

---

## 1. Where the code stands

- **Layers everywhere**: each feature has the `domain/ data/ providers/ screens/ widgets/` it
  needs; the feature graph is declared in `test/architecture/architecture_test.dart` and
  `knownViolations` is empty — a new violation is fixed in the code, never listed.
- **Domain**: pure models with `==`, drafts (`BirthdayDraft`), typed failures (`AuthFailure`,
  `BookFailure`, `ContactImportFailure`), rules as functions taking `today` or `now`
  (`birthday_dates.dart`, `reminder_plan.dart`); only `clockProvider`/`todayProvider` read the
  clock.
- **Data**: SDKs injected from `core/providers/`; Firestore mapping private to each repository,
  tolerant on read; multi-document writes through `writeInBatches`.
- **State**: session-scoped streams on `currentUidProvider`; one controller per family of actions
  (`BirthdayEditor`, `CategoryEditor`, `BookEditor`…) with optimistic writes whose failures a
  host screen announces; side effects (`reminderSyncProvider`) activated from `app/`.
- **Composition**: `app/` owns the router, the shell and the bootstrap. go_router (`app/router/`,
  `appRouterProvider`) redirects on `authAccessProvider`; the tabs are branches of a
  `StatefulShellRoute` that keep their state; features navigate by path
  (`core/routing/app_routes.dart`) with `context.go` / `context.push`.
- **Auth**: the session (`authUserProvider`, Firebase `userChanges`), the biometric lock
  (`biometricLockProvider`) and the actions (`AuthController`) are separate; the router picks
  the screen from `authAccessProvider` (pure rules `authAccess`, `accessRedirect`). The
  fingerprint only unlocks the session of its own account. No legacy notifier is left.

**Not verified outside the tests yet** — delete each line once done:
- `firestore.rules` deployed by the maintainer (owner pinned on update, M0):
  `firebase deploy --only firestore:rules`.
- M2–M6 and M9 on the phone: sign-in (email and sign-up land on the app, not on the form; Google,
  where a cancel stays silent; anonymous), a restored session locked behind the fingerprint
  without the app flashing first, unlock, a revoked fingerprint (`biometricToken` changed in the
  console) signing out with « La connexion biométrique n'est plus valide… », sign-out with the
  fingerprint on (lock only) and off,
  enabling and disabling the fingerprint in the settings, birthday with a photo (kept when editing
  without a new one), category created offline (the sheet closes at once), contacts import
  refused (« Permission refusée. »), account deletion with the fingerprint on or off (birthdays,
  books and profile gone, no error), reminders at 10:00 on J-0 and J-7 without duplicates after
  the update, birthdays tab shown again after signing back in.
- M7 on the phone: a tab keeps its scroll and search when you come back to it, the settings
  open above the tab and back returns to it, back from the e-mail sign-in returns to the
  sign-in choice, the system back button on a tab leaves the app.

**Done**

| Step | Date | Outcome |
|------|------|---------|
| M0 | 2026-10-08 | architecture test, stricter lints, `riverpod_lint`, document owner pinned in the rules |
| M1 | 2026-10-08 | infrastructure and session providers; SDKs injected into repositories and services |
| M2 | 2026-10-09 | data derived from the session, controllers with optimistic writes |
| M3 | 2026-10-09 | pure domain models, Firestore mapping inside repositories, date rules |
| M4 | 2026-10-09 | shell and route table in `app/`, paths in `core/routing/`, `settings` feature |
| M5 | 2026-10-09 | typed failures, no `AppLocalizations` in state, optimistic category writes |
| M6 | 2026-10-09 | `reminders` feature plans J-0/J-7; `NotificationService` only schedules |
| M9 | 2026-10-11 | auth split: session stream, biometric lock, `AuthController`; `App` waits for both before choosing a screen |
| M8 | 2026-10-11 | concept names (`UserProfile`, `Birthday`, `Book`); every screen and widget test mirrors `lib/`; the data move stays open (§3) |
| M7 | 2026-10-11 | go_router 17.5.0: router provider with access redirects, tabs as stateful branches, paths `/auth/login`, `/birthdays`, `/scanner` |

The commit messages of those days hold the details. Bugs found on the way (DST day counts,
batches over 500 writes, books left behind by account deletion, blank names, error shown on a
cancelled Google sign-in, sign-in screens left on top of the app, account deletion failing with
the fingerprint on, a fingerprint opening the app without a Firebase session or on another
account's session, a sign-out that left the session open) are fixed and tested.

## 2. Open debt

| # | Debt | Evidence | Consequence | Step |
|---|------|----------|-------------|------|
| A15 | Book lookup failures flattened | `BookRepository.fetchBookByIsbn` returns `null` for every failure but the quota (HTTP error, network, parsing), as for an unknown ISBN; a volume without title gets `'Unknown Title'`, an English UI string in the data layer | offline, a scan reads « Livre non trouvé »; untranslatable text | local fix: `BookFailure.network`, empty title worded by the UI |
| A16 | `invalid-credential` worded as unknown | with email-enumeration protection (on by default for projects created since September 2023), Firebase Auth answers a wrong email or password with `invalid-credential`; `AuthRepository` maps it to `AuthFailure.unknown` | « Une erreur est survenue. » after a typo in the password (check on the phone) | local fix: `AuthFailure.invalidCredentials` and its ARB message |

UX debt (contrast, 200 % text, labels, raw colors, dates without `DateFormat`) is tracked in the
ux-ui backlog (`ux-backlog.md`), not here.

## 3. Remaining steps

Recommended order: M10 only on a concrete need. Local fixes (A15, A16) go with any change
touching their files. Sizes: S < 1 h, M ≈ half a day, L ≈ a day (agent + review).

### With B3/B4 — notification taps open a page · S
- Left out of M7 until a page exists to open: the payload of a reminder is a route path
  (`ReminderNotification`), `NotificationService` hands taps
  (`onDidReceiveNotificationResponse`, and the launch details on a cold start) to the router,
  which `go`es there behind the access redirects.

### M10 — Per-user collections · L · system change, only on a concrete need
- Left out of M8: move `birthday`/`books` to `user/{uid}/…` — data migration with dual read,
  rules update deployed by the maintainer, one release of overlap.
- Worth it only for a concrete need: sharing, rules complexity, cost. Brief and approval first.

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
6. Update this file: a line in *Done*, the cleared debt deleted, discoveries added to §2; general
   gotchas go to `patterns.md` §15.
7. Commit per the git-workflow skill: one intent per commit, `git add <paths> && git commit`.
