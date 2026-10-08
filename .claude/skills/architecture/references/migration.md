# Audit and migration plan — from today's code to the target

Audit of 2026-10-07 (commit `46359f3`): 53 hand-written Dart files in `lib/` (~7 100 lines),
5 features, 281 tests green, `flutter analyze` clean with strict casts/inference/raw types. Update this file as steps land:
tick the step, delete the debt it cleared, add what you discover.

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

The architecture test reports 25 violations today (they are the `knownViolations` baseline).
Plus what imports can't show:

| # | Debt | Evidence | Consequence | Step |
|---|------|----------|-------------|------|
| A1 | Imperative session lifecycle | `app/bootstrap/app_initializer.dart` calls `startListening(uid)` on two notifiers and `loadUser`/`createUser`; `settings_screen.dart` calls `clear()` on three notifiers | forgotten resets leak the previous account's data; races between auth and streams; session knowledge spread in UI | M2 |
| A2 | Feature cycles | `user → birthday` (`user_provider.dart` deletes birthdays and clears their notifier; `settings_screen.dart`), `auth → user` (`signup_screen.dart` creates the profile) | features can't be changed or tested alone | M4 |
| A3 | Models coupled to SDKs | `BirthdayModel.fromFirestore(QueryDocumentSnapshot)`, `Timestamp` in models, `BirthdayCategory.iconData` (Flutter), `CreateBirthdayInput.pictureFile` (`XFile`), widgets importing `data/models` | domain logic untestable without Firebase; UI depends on the data layer | M3 |
| A4 | Rules duplicated and clock-bound | next occurrence in `birthday_extensions.dart` **and** `notification_service.dart`; `DateTime.now()` in 9 places; J-0/J-7/10:00 policy inside the plugin wrapper | divergent results, date tests depend on the real day, B6 (custom reminders) blocked | M3, M6 |
| A5 | Singletons bypass DI | `NotificationService.instance` (birthday_provider, app_initializer), `BiometricService.instance` (auth_provider, settings_screen), `FirebaseFirestore.instance` defaults | can't override in tests or per environment | M1 |
| A6 | Words and context in state | `AuthNotifier` methods take `AppLocalizations`; `errorMessage` strings in state; `Exception('Contacts permission denied')`; `GoogleBooksQuotaExceededException` defined in `data/` and caught by a screen | locale switches and tests leak into logic; untyped errors | M5 |
| A7 | Navigation split three ways | `AppRoutes` in `app/router` (features can't import it) so features push raw `'/login'`, `'/signup'`; `HomeScreen`/`BookScannerScreen` import `SettingsScreen` and push `MaterialPageRoute`; the shell lives in `features/home/`; `MainTab { birthdays, scanner }` sits in `core/providers/` and `core/common/bottom_bar.dart` reads it | core knows features; routes drift; no place for deep links | M4, M7 |
| A8 | Small correctness bugs | `AuthNotifier.initializeAuth()` never cancels its `authStateChanges()` subscription; `UserNotifier._repository` and `BookScannerNotifier._repository` call `ref.watch` from methods; `appConfigProvider` is unused while `BookRepository` reads `String.fromEnvironment` itself; `BirthdayRepository.deleteBirthday` reads the document before deleting it (the rules already enforce ownership) | leaks, rebuild surprises, duplicated config, slower optimistic deletes | M1, M2 |
| A9 | State boilerplate | `BirthdayState`/`BookScannerState`/`UserState` hand-roll `isLoading`/`isCreating`/`error` around data that `AsyncValue` models natively | more code, more `copyWith`, inconsistent loading/error handling | M2 |
| A10 | Tooling gaps | `require_trailing_commas` is a no-op since Dart 3.7; 15 `unawaited_futures` hits; no `riverpod_lint`; the widget harness keeps Riverpod's automatic retry | silent fire-and-forget futures; slow, flaky error tests later | M0 |
| A11 | Rules gaps | `firestore.rules`: `birthday` and `books` updates check the stored `uid` but not the new one (`request.resource.data.uid == resource.data.uid` missing), so a document can be handed to another account; `category` is a shared collection any signed-in user can read and create (by design today, revisit with backlog B7) | data integrity relies on client code | M0 |

## 3. Roadmap

Each step ships alone: tests green, analyzer clean, architecture test green with a shorter
`knownViolations`. Sizes: S < 1 h, M ≈ half a day, L ≈ a day (agent + review).

### M0 — Safety net and tooling · S · no behaviour change
- Copy `assets/foundation/test/architecture/architecture_test.dart` → `test/architecture/`; run it
  (green with the baseline).
- `analysis_options.yaml`: drop `require_trailing_commas`; add `unawaited_futures`,
  `avoid_dynamic_calls`, `unnecessary_ignore`, `cancel_subscriptions`, `close_sinks`,
  `only_throw_errors`, `test_types_in_equals`; fix the 15 + 1 hits (wrap intended fire-and-forget
  in `unawaited(...)`). `discarded_futures` stays off (24 hits, mostly widget callbacks: noise).
- `riverpod_lint` (approval: new analyzer plugin), nothing in `pubspec.yaml` — append to
  `analysis_options.yaml`:
  ```yaml
  plugins:
    riverpod_lint: 3.1.9
  ```
  Then restart the IDE's analysis server and check with `dart analyze` (`flutter analyze` ignores
  plugins): 4 infos today, `ThemeNotifier.isDark` and 3 public fields on test fakes.
- `test/support/test_harness.dart`: `ProviderScope(retry: (_, _) => null, …)`.
- `firestore.rules`: pin `uid` on `birthday`/`books` updates (A11); the maintainer deploys with
  `firebase deploy --only firestore:rules`.
- Commits: `TEST: add architecture boundary test`, `CHORE: tighten analyzer lints`,
  `CHORE: enable riverpod_lint plugin`, `TEST: disable provider retry in harness`,
  `FIX(firebase): forbid changing a document's owner`.

### M1 — Infrastructure providers · M · no behaviour change
- Copy `assets/foundation/lib/core/providers/{firebase_providers,clock_provider}.dart` and
  `assets/foundation/lib/features/auth/providers/session_providers.dart`, with their tests
  (`assets/foundation/README.md`). An earlier brick may already have installed some of them.
- Repositories take their SDKs as required constructor arguments, wired from
  `firestoreProvider`/`firebaseAuthProvider`; repository tests pass fakes positionally.
- `notificationServiceProvider`, `biometricServiceProvider` (singletons stay for `main()` only);
  features stop reading `.instance` (A5).
- `BookRepository` gets its key from `appConfigProvider` and an `httpClientProvider` (A8).
- Fix A8 bugs: cancel the auth subscription in `ref.onDispose`; `ref.read` in methods.
- Commit: `REFACTOR(core): inject Firebase and services through providers`.

### M2 — Session-derived data · L · split per feature (M2a birthday, M2b book_scanner, M2c user)
- `birthdaysProvider`, `savedBooksProvider`, `userProfileProvider`: `StreamProvider`s on
  `currentUidProvider` (patterns §6). Derived providers keep their names, read `.value`.
- Writes move to controllers: `BirthdayEditor` (optimistic create/update/delete),
  `ContactImport` (awaited), `BookScanner` lookup (awaited) (patterns §9).
- Notification scheduling leaves `BirthdayNotifier` for `reminderSyncProvider`, activated in
  `app/` (patterns §10); it moves to `features/reminders/` in M6.
- `AppInitializer` → `app/bootstrap/session_bootstrap.dart`: reacts to `currentUidProvider`
  (ensure the profile exists, request notification permission); no stream starts, no `clear()`.
- Delete `BirthdayState`/`BookScannerState`/`UserState` once unused (A9); rewrite their tests as
  provider tests over fake repositories; drop the matching fake Notifiers in `test/support`.
- Commits: `REFACTOR(birthday): derive birthdays from the session`, … one per feature.

### M3 — Domain extraction · M per feature
- `data/models/*` → `domain/`; Firestore mapping → private functions in the repository;
  `data/repositories/*` → `data/`.
- `birthday_extensions.dart` splits: date rules → `domain/birthday_dates.dart` (explicit
  `today`, reused by notifications); labels/colors/icons → `widgets/category_display.dart` (A3, A4).
- `CreateBirthdayInput` → `BirthdayDraft` with picture bytes instead of `XFile`.
- `GoogleBooksQuotaExceededException` → `domain/book_failure.dart`.
- Clears the `ui-no-backend`, `data-no-ui` and birthday `layout` lines.
- Commits: `REFACTOR(birthday): move models and date rules to domain`, …

### M4 — Break cycles, move composition to `app/` · M
- New feature `settings` (`screens/settings_screen.dart` from `user`, `AccountDeletion`
  controller, patterns §13); `featureDependencies['settings'] = {'auth', 'user', 'birthday'}`.
- Profile creation leaves `signup_screen.dart` (session bootstrap does it) → no `auth → user`.
- `features/home/main_screen.dart` → `app/shell/main_shell.dart`; `MainTab` +
  `navigationProvider` → `app/shell/`; `BottomBar` becomes dumb (selected index + callback).
- `core/routing/app_routes.dart` holds the paths; `app/router` keeps the table; features use
  `AppRoutes.*`, settings opens by path (A7).
- Remove `home` from `featureDependencies`. Clears every `feature-graph`, `screens-private` and
  remaining `layout` line.
- Commits: `REFACTOR(app): move shell and route paths out of features`,
  `REFACTOR(settings): extract settings feature`.

### M5 — Typed failures, words in the UI · M
- `AuthFailure` (enum) mapped from `FirebaseAuthException.code` in `AuthRepository`;
  `AuthNotifier` methods lose `l10n`; `widgets/auth_failure_text.dart` maps to ARB keys that
  already exist (`errorWeakPassword`, …).
- Same for contacts permission and book lookup failures. Clears the `state-no-ui` line; the
  baseline is empty after M3–M5.
- Commit: `REFACTOR(auth): expose typed failures instead of messages`.

### M6 — Reminders feature · M · prepares backlog B3/B6
- `features/reminders/`: `domain/reminder_plan.dart` (pure: birthdays + today + preferences →
  planned notifications: J-0, J-7, 10:00, ages), `providers/reminder_sync_provider.dart`.
- `NotificationService` keeps only plugin work: init, permissions, schedule what it is given,
  cancel stale ids.
- Commit: `REFACTOR(reminders): extract reminder planning from NotificationService`.

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
4. Run `dart format`, `flutter analyze`, `dart analyze` (plugins) once M0 is in, the touched
   features' tests, then the whole suite and `test/architecture/`.
5. Remove the cleared lines from `knownViolations`; update this file (tick the step, remove fixed
   debt, note discoveries).
6. Commit per the git-workflow skill: one intent per commit, `REFACTOR(scope): …`.
