# Migration plan — what remains between the code and the target

The 2026-10-07 audit (commit `46359f3`) and steps M0–M6 and M9 (2026-10-08/11) brought the code
to the target, except what this file lists. Keep it current: when a step lands, add a line to
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
- **Composition**: `app/` owns the shell, the route table and the bootstrap; features navigate by
  path (`core/routing/app_routes.dart`).
- **Auth**: the session (`authUserProvider`, Firebase `userChanges`), the biometric lock
  (`biometricLockProvider`) and the actions (`AuthController`) are separate; `App` picks its
  screen from `authAccessProvider` (pure rule `authAccess`). No legacy notifier is left.

**Not verified outside the tests yet** — delete each line once done:
- `firestore.rules` deployed by the maintainer (owner pinned on update, M0):
  `firebase deploy --only firestore:rules`.
- M2–M6 and M9 on the phone: sign-in (email and sign-up land on the app, not on the form; Google,
  where a cancel stays silent; anonymous), a restored session locked behind the fingerprint
  without the app flashing first, unlock, sign-out with the fingerprint on (lock only) and off,
  enabling and disabling the fingerprint in the settings, birthday with a photo (kept when editing
  without a new one), category created offline (the sheet closes at once), contacts import
  refused (« Permission refusée. »), account deletion with the fingerprint on or off (birthdays,
  books and profile gone, no error), reminders at 10:00 on J-0 and J-7 without duplicates after
  the update, birthdays tab shown again after signing back in.

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

The commit messages of those days hold the details. Bugs found on the way (DST day counts,
batches over 500 writes, books left behind by account deletion, blank names, error shown on a
cancelled Google sign-in, sign-in screens left on top of the app, account deletion failing with
the fingerprint on) are fixed and tested.

## 2. Open debt

| # | Debt | Evidence | Consequence | Step |
|---|------|----------|-------------|------|
| A7 | Navigation without deep links | named routes, paths in `core/routing/app_routes.dart`; a notification tap can't open a page, no URL state | B3/B4/B5 need a router | M7 |
| A15 | Book lookup failures flattened | `BookRepository.fetchBookByIsbn` returns `null` for every failure but the quota (HTTP error, network, parsing), as for an unknown ISBN; a volume without title gets `'Unknown Title'`, an English UI string in the data layer | offline, a scan reads « Livre non trouvé »; untranslatable text | local fix: `BookFailure.network`, empty title worded by the UI |
| A16 | `invalid-credential` worded as unknown | with email-enumeration protection (on by default for projects created since September 2023), Firebase Auth answers a wrong email or password with `invalid-credential`; `AuthRepository` maps it to `AuthFailure.unknown` | « Une erreur est survenue. » after a typo in the password (check on the phone) | local fix: `AuthFailure.invalidCredentials` and its ARB message |
| A17 | Yearly reminders keep a stale age | notifications repeat each year (`DateTimeComponents.dateAndTime`) with the age written when scheduled; right only because the app re-plans at launch and on every change | wrong age if the app isn't opened for a year | with B6: drop the age from repeated texts, or schedule the next occurrences one by one |

UX debt (contrast, 200 % text, labels, raw colors, dates without `DateFormat`) is tracked in the
ux-ui backlog (`ux-backlog.md`), not here.

## 3. Remaining steps

Recommended order: M7 with the first of B3/B4/B5, M8 only on need. Local fixes (A15, A16) go
with any change touching their files. Sizes: S < 1 h, M ≈ half a day, L ≈ a day (agent +
review).

### M7 — go_router (A7) · M · approval, with the first of B3/B4/B5
- Decision D9: go_router 18 depends on `material_ui` (or pin 17.x); a router provider;
  `StatefulShellRoute` for the tabs of `app/shell/`; notification payload = path.
- Paths stay in `core/routing/app_routes.dart`; `app/router/` builds the router; redirects read
  `authAccessProvider`.
- Commit: `FEAT(app): route with go_router` (or `REFACTOR` if invisible to users).

### M8 — Optional cleanups · approval
- Rename the `XModel` types when their feature is touched (`UserModel` → `UserProfile`,
  `BirthdayModel` → `Birthday`, `BookModel` → `Book`).
- Move the older screen and widget tests from the feature root to the mirror layout
  (`test/features/<f>/screens/`, `widgets/`).
- Move `birthday`/`books` to `user/{uid}/…` (data migration with dual read, rules update, one
  release of overlap) — only on a concrete need (sharing, rules complexity, cost).

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
