# Audit and migration plan — from today's code to the target

Audit of 2026-10-07 (commit `46359f3`): 53 hand-written Dart files in `lib/` (~7 100 lines),
5 features, 281 tests green, `flutter analyze` clean with strict casts/inference/raw types.
Update this file as steps land: tick the step, delete the debt it cleared, add what you discover.

**Progress** — M0 to M6 done (2026-10-08/09). Next: M7 and M8, both on approval (see their
steps); open debt A7 and A14.

## Contents
1. What already works
2. Debt, with evidence
3. Roadmap (M0 → M8)
4. How to run a step

---

## 1. What already works

Keep these; the target builds on them.
- Feature-first folders, an `app/` composition root, `core/` that never imports a feature.
- Repositories with an injectable Firestore, hand-written immutable models, `copyWith`
  everywhere, value objects at the `core` boundary (`BirthdayReminder`, `ImportedBirthday`).
- Riverpod 3 Notifiers with `ref.mounted` guards and `try/finally` loading resets.
- A strong test culture: mirrored tests, shared fakes (`test/support/fake_providers.dart`), a
  widget harness, `fake_cloud_firestore`, `firebase_auth_mocks`, `mock_exceptions`.
- Absolute imports, French doc comments, ARB-only strings, exact dependency pins.

## 2. Debt, with evidence

The architecture test reported 25 violations at the audit (the `knownViolations` baseline; 8
left after M3, 1 after M4, none since M5).
Plus what imports can't show:

| # | Debt | Evidence | Consequence | Step |
|---|------|----------|-------------|------|
| A7 | Navigation without deep links | named routes with paths in `core/routing/app_routes.dart` (since M4); notification taps can't open a page, no URL state | B3/B4/B5 need a router | M7 |
| A14 | `AuthNotifier` mixes three concerns | one `Notifier<AuthState>` holds the Firebase session, the biometric lock (`canUseBiometrics`, `biometricUid`) and every auth action with an `isLoading` flag; screens read `state.failure` after awaiting a `bool` | hard to test and to extend (onboarding, account linking); the lock rules live in UI-facing state | after M6, own brief (phone check of the biometric flows) |

Cleared: A10 (tooling gaps) and A11 (`uid` not pinned on updates) by M0; A5 (singletons bypass DI)
and most of A8 by M1; A1 (imperative session lifecycle), the rest of A8 (read-before-delete) and
A9 (state boilerplate, except `AuthState` → A14) by M2; A3 (models coupled to SDKs) and the
birthday half of A4 by M3; A2 (undeclared feature edges), the M4 half of A7 and A13 (books left
behind by account deletion) by M4; A6 (words and context in state) and A12 (awaited category
writes) by M5, with the message half of A14; the rest of A4 (reminder rules in the plugin wrapper) by M6.

## 3. Roadmap

Each step ships alone: tests green, analyzer clean, architecture test green with a shorter
`knownViolations`. Sizes: S < 1 h, M ≈ half a day, L ≈ a day (agent + review).

### M0 — Safety net and tooling · done 2026-10-08
- `TEST: add architecture boundary test` — `test/architecture/`, 25 known violations.
- `CHORE: tighten analyzer lints` — 7 rules added (`unawaited_futures`, `avoid_dynamic_calls`,
  `unnecessary_ignore`, `cancel_subscriptions`, `close_sinks`, `only_throw_errors`,
  `test_types_in_equals`), `require_trailing_commas` dropped; 15 intended fire-and-forget calls
  (haptics, a microtask, the sign-out overlay, scanner restarts) wrapped in `unawaited`,
  behaviour unchanged. `discarded_futures` stays off (24 hits in widget callbacks: noise).
- `CHORE: enable riverpod_lint plugin` — `plugins: riverpod_lint: 3.1.9` in
  `analysis_options.yaml`; `ThemeNotifier.isDark` made private; three legacy test fakes keep
  their spy fields behind `// ignore: riverpod_lint/avoid_public_notifier_properties`.
- `TEST: disable provider retry in harness`.
- `FIX(firebase): forbid changing a document's owner` — **the maintainer deploys it**
  (`firebase deploy --only firestore:rules`); not run in the emulator (no Firebase CLI here).
- Learned: plugin diagnostics only show with `dart analyze` and in the IDE (restart its analysis
  server after editing `plugins:`); a `// ignore: riverpod_lint/<rule>` comment doesn't trip
  `flutter analyze`'s `unnecessary_ignore`.

### M1 — Infrastructure providers · done 2026-10-08
- `REFACTOR: add infrastructure and session providers` — the foundation files with their tests,
  plus `httpClientProvider`.
- `REFACTOR: inject SDKs into repositories` — required named parameters (Dart 3.12 private named
  parameters: `BirthdayRepository({required this._firestore})`, called with `firestore:`),
  wired from `firestoreProvider`/`firebaseAuthProvider`/`googleSignInProvider` (in `auth/data`);
  `BookRepository` takes its key from `appConfigProvider` and its client from
  `httpClientProvider`.
- `REFACTOR: read services through providers` — `notificationServiceProvider`,
  `biometricServiceProvider`; `.instance` is read by `main()` and these providers only.
- `FIX(auth): cancel auth state subscription on dispose`;
  `REFACTOR: read repositories with ref.read in methods`.
- Learned: with Riverpod 3, a `ref.read` after an `await` throws once the notifier is disposed
  (tests dispose containers early) — read dependencies before the first `await`.

### M2 — Session-derived data · done 2026-10-09
- `REFACTOR(birthday): derive birthdays from the session` — `birthdaysProvider` on
  `currentUidProvider`; `BirthdayEditor` (optimistic writes, the home screen reports failures and
  replaces the « supprimé » snackbar it contradicts); `ContactImport` (local part awaited, batched
  writes not awaited, double tap ignored); `reminderSyncProvider` activated by `App` — sign-out
  now also cancels the local reminders; delete without read-before-write.
- `REFACTOR(book_scanner): derive saved books from the session` — `savedBooksProvider`,
  `IsbnLookup` (awaited), `BookEditor` (optimistic, the screen reports failures).
- `REFACTOR(user): derive the profile from the session` — `userProfileProvider` streams
  `user/{uid}`; theme and locale derive from it; `UserProfileEditor` writes field by field;
  `AppInitializer` creates a missing profile reactively (typed sign-up names travel through
  `signUpNamesProvider` in `auth`, so compound first names stay exact and `auth` no longer imports
  `user`); `AccountDeletion` erases the account data before the auth account goes.
- Tests: fake **repositories** in `test/support` (`RecordingBirthdayRepository`,
  `RecordingBookRepository`, `RecordingUserRepository` whose stream reflects writes); every fake
  Notifier except `FakeAuthNotifier`/`FakeCategoryNotifier` is gone; moved tests follow the mirror
  layout (`providers/`, `test/app/bootstrap/`). Architecture debt 25 → 23.
- Learned:
  - Writing a whole document read a moment earlier loses concurrent edits (theme then language):
    write the changed fields only (`update`, `FieldValue.arrayUnion`).
  - `autoDispose` controllers need a host screen listening (home, scanner, settings) to keep them
    alive and to report late failures; a sheet alone is not enough.
  - A failure that contradicts the snackbar on screen must replace it (`hideCurrentSnackBar`),
    otherwise it queues behind it for 4 s.
  - Riverpod notifies dependents lazily; a provider nobody listens to is paused — tests listen,
    then read.
  - `fake_cloud_firestore` applies a transaction one tick late to snapshot listeners.

### M3 — Domain extraction · done 2026-10-09
- `REFACTOR(user|book_scanner|birthday): move the … model(s) to domain` — every model is a pure
  Dart primary-constructor class with `==` in `domain/`; Firestore (and Google Books) mapping is
  private to the repository, with tolerant reads; repositories sit in `data/`. `BookModel` and
  `BirthdayModel` lose the owner `uid` (the repository writes it); `BookFailure.quotaExceeded`
  replaces `GoogleBooksQuotaExceededException`; the scan date comes from `clockProvider` and null
  fields are no longer written.
- `CreateBirthdayInput` → `BirthdayDraft`; photos travel as bytes (read when picked, decoded once
  by the repository instead of `base64Decode` in every `build`); a birthday document without a
  date is skipped instead of failing the whole list.
- `REFACTOR(birthday): extract birthday date rules` — `domain/birthday_dates.dart`
  (`nextOccurrence`, `daysUntilNext`, `ageOn`, `sortedByNext`, `nextBirthdays`, all taking
  `today`); providers and widgets read `todayProvider`, so lists and ages refresh at midnight;
  `widgets/category_display.dart` (icon, color, label), `widgets/birthday_display.dart`
  (formatted date); `extensions/` is gone.
- `FIX(birthday): count days to a birthday across DST` — found while extracting.
- `REFACTOR(auth): move the auth repository to data/`.
- Left for M6: `NotificationService` keeps its own next-occurrence rule — `core` can't import
  `birthday/domain`; the `reminders` feature will plan from `birthday_dates.dart`.
- Tests: mapping tests moved from model tests to repository tests (complete and old-shape
  documents); `tester.pumpLocalizedContext()` for display extensions. Architecture debt 23 → 8.
- Learned:
  - Day counts between two local midnights lose an hour at the spring DST change: count on UTC
    dates.
  - Firestore `orderBy` leaves out documents missing the field: always write the sort key.
  - `MemoryImage` is keyed by its bytes instance: decoding base64 in `build` re-decodes the image
    on every rebuild.
  - Widgets watching `todayProvider` need no override in widget tests: the test unmounts the
    `ProviderScope` before checking timers, which cancels the midnight timer. Pin the day only
    when the assertion depends on it.

### M4 — Break cycles, move composition to `app/` · done 2026-10-09
- `REFACTOR(app): move shell and route paths out of features` — `features/home/main_screen.dart`
  → `app/shell/main_shell.dart` (`MainShell`); `MainTab` + `navigationProvider` → `app/shell/`;
  `BottomBar` is stateless (destinations, selected index, callback; labels `tabBirthdays`,
  `tabScanner` in the ARB instead of hard-coded French); `AppRoutes` paths in
  `core/routing/app_routes.dart`, the table stays in `app/router`; features navigate by path
  (settings, login, signup); `home` leaves `featureDependencies`.
- `FIX(app): reset the selected tab with the session`.
- `REFACTOR(settings): extract the settings feature` — `SettingsScreen` and `AccountDeletion`
  leave `user`, which no longer imports `birthday`.
- `FIX(birthday): erase accounts with over 500 birthdays` — `writeInBatches` extension in
  `core/extensions/firestore_extensions.dart`, used by every multi-document write.
- `FIX(settings): erase scanned books with the account` — A13;
  `featureDependencies['settings'] = {'auth', 'user', 'birthday', 'book_scanner'}`.
- Also: the ux-ui snapshot script follows the new paths and providers (it was broken since M2:
  it isn't compiled by the suite — `.claude/` is a hidden folder the analyzer skips).
- Architecture debt 8 → 1 (`auth_provider.dart → app_localizations.dart`, M5).
- Learned:
  - `fake_cloud_firestore` enforces the 500-operation batch limit: a test with 501 documents
    proves a batching bug.
  - A test moved one folder deeper keeps its relative `../support/` imports: fix them by hand
    (the analyzer flags them at once).

### M5 — Typed failures, words in the UI · done 2026-10-09
- `REFACTOR(auth): expose typed failures instead of messages` — `AuthFailure` enum in
  `auth/domain/`; `AuthRepository` maps `FirebaseAuthException.code` (`_guard`, stack trace
  kept); `AuthNotifier` methods take no `AppLocalizations`; `AuthState.failure` replaces
  `errorMessage` and each operation clears it (a stale message could show after a cancelled
  biometric prompt); `AuthState` gets `==`; `widgets/auth_failure_text.dart` picks the ARB key.
  The last `knownViolations` line is gone: the baseline is empty.
- `FIX(auth): stay silent when Google sign-in is cancelled` — found on the way.
- `REFACTOR(birthday): type the contacts permission failure` — `ContactImportFailure`; any other
  import error now shows the generic message instead of « Permission refusée ».
- `REFACTOR(birthday): write categories optimistically` — `CategoryEditor` (`AsyncNotifier<void>`)
  replaces `CategoryNotifier`; category ids are generated client-side (`newCategoryId`), the
  sheet closes at once, the home screen announces a failure (`errorSavingCategory`); a shared
  `RecordingCategoryRepository` replaces six per-file stubs.
- Book lookup: `BookFailure.quotaExceeded` since M3; network errors still read as « not found »
  (UX follow-up, not architecture).
- Left (A14): splitting `AuthNotifier` into a session stream, a biometric lock and action
  controllers changes the sign-in, lock and sign-out flows — its own brief, checked on the phone.
- Learned: `firebase_auth_mocks` asserts that `signInAnonymously` gets an anonymous mock user;
  build the mock to match the call under test.

### M6 — Reminders feature · done 2026-10-09 · prepares backlog B3/B6
- `REFACTOR(reminders): extract reminder planning from NotificationService` — new feature
  `reminders` (`featureDependencies['reminders'] = {'birthday'}`): `domain/reminder_plan.dart`
  (`planReminders(birthdays, now:)` → `PlannedReminder` J-0 and J-7 at 10:00 with the age
  reached, `ReminderPolicy` constants, notification ids with the same formula as before so
  phones replace their scheduled reminders instead of doubling them), built on
  `birthday_dates.dart`; `providers/reminder_sync_provider.dart` (moved from `birthday`) plans
  with `clockProvider` and maps to the `core` value object `ReminderNotification`.
- `NotificationService` keeps plugin work only: init, permissions, cancel stale ids, schedule each
  `ReminderNotification` at its local time with the injected texts. No date rule, no
  `DateTime.now()`.
- Found on the way: the J-7 date was computed with `Duration(days: 7)`, one day early when the
  week spanned the spring DST change; now counted in calendar days (tested).
- Not done: a yearly repeating notification keeps the age written when it was scheduled; the
  app re-plans at every launch and on every change, so it only shows if the app isn't opened
  for a year. Preferences (B6) will add a `ReminderPreferences` parameter to `planReminders`.

### M7 — go_router · M · approval, with the first of B3/B4/B5
- See decision D9 (material_ui coupling of go_router 18, router provider, `StatefulShellRoute`,
  notification payload = path).
- Commit: `FEAT(app): route with go_router` (or `REFACTOR` if invisible to users).

### M8 — Optional cleanups · approval
- Rename legacy `XModel` types (`UserModel` → `UserProfile`, …) when their feature is touched.
- Move `birthday`/`books` to `user/{uid}/…` (data migration with dual read, rules update, one
  release of overlap) — only if a concrete need appears (sharing, rules complexity, cost).

## 4. How to run a step

1. Re-read the step and the current code: the audit ages; adjust before starting.
2. Behaviour-preserving first: if a behaviour isn't covered by a test, add the test before
   moving code.
3. Move with `git mv` (history follows), then fix imports; keep each commit compiling.
4. Run `dart format`, `flutter analyze`, `dart analyze` (runs `riverpod_lint`), the touched
   features' tests, then the whole suite and `test/architecture/`.
5. Remove the cleared lines from `knownViolations`; update this file (tick the step, remove fixed
   debt, note discoveries).
6. Commit per the git-workflow skill: one intent per commit, `REFACTOR(scope): …`.
