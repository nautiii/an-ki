---
paths:
  - "test/**"
---

# Tests

Per-layer patterns: architecture skill, `references/patterns.md` §14. UI checks: ux-ui skill,
`references/accessibility.md` §7 and `references/flutter-recipes.md` §11.

## Layout

- `test/` mirrors `lib/` file by file: `lib/features/<f>/<layer>/x.dart` →
  `test/features/<f>/<layer>/x_test.dart`; a flow over several screens →
  `test/features/<f>/<flow>_flow_test.dart` (`create_birthday_flow_test.dart`). Nothing else
  sits at a feature root.
- Shared fakes and helpers live in `test/support/`: reuse them, don't redefine them per file
  (`tester.pumpLocalizedContext()` gives a French `BuildContext` for display extensions).
- Never touch real Firebase, network or platform channels. Use `FakeFirebaseFirestore`,
  `MockFirebaseAuth` (firebase_auth_mocks), `MockClient` (http), `mock_exceptions`,
  and the doubles in `test/support/`: `FakeBiometricChannels`, `FakeGoogleSignInPlatform`,
  `FakeMobileScannerPlatform.install()`, `mockNetworkImages`.

## Per layer

- **Domain**: plain `test()`, dates passed explicitly; nothing depends on the real day.
- **Repository**: the real class on `FakeFirebaseFirestore`; assert per-user isolation, failure
  translation, batch behaviour, old-shape documents. Force errors with
  `whenCalling(Invocation.method(#delete, null)).on(docRef).thenThrow(…)`.
- **Providers**: `ProviderContainer.test(retry: (_, _) => null, overrides: […])` (disposes
  itself). Listen before awaiting — `container.listen(p, (_, _) {})` — or a paused provider never
  emits. Assert `AsyncValue` transitions.
- Fake **repositories** (`class _FakeX extends Fake implements XRepository`), not notifiers: they
  exercise the real logic. Start a notifier in a given state with `overrideWithBuild`; families
  use `overrideWith2` (`overrideWith` is deprecated since Riverpod 3.2). Shared fakes:
  `RecordingBirthdayRepository`, `RecordingBookRepository`, `RecordingCategoryRepository`,
  `RecordingUserRepository` (its `watchUser` reflects writes, like the Firestore cache),
  `FakeAuthRepository` (its session follows its calls) and `FakeBiometricService`; the sign-in
  screens start from `authOverrides`, `failingAuthOverrides` or `loadingAuthOverrides`
  (`test/support/auth_overrides.dart`). A widget that only needs a signed-in user gets
  `currentUidProvider.overrideWithValue('fake-uid')`.
- **Widgets and screens**: `await tester.pumpHarness(widget, overrides: […])` (French locale,
  800×1200). A non-empty `overrides` list **replaces** `defaultTestOverrides`, it doesn't extend
  it. Pin async data with `xProvider.overrideWithValue(const AsyncData(…))`. Cover loading, empty,
  data and error; accessibility with `meetsGuideline(androidTapTargetGuideline)`,
  `meetsGuideline(labeledTapTargetGuideline)` and `find.bySemanticsLabel`.
- The harness disables Riverpod's automatic retry (`retry: (_, _) => null`): a provider in error
  renders its error at once, with no retry timer left pending.
- `test/architecture/` runs with the suite: a new feature is declared in `featureDependencies`,
  fixed debt is removed from `knownViolations`, a new violation is fixed in the code.
- `TestHarness` doesn't apply `AppTheme`: widget tests check behaviour; look and contrast are
  checked with the ux-ui snapshot tool.

## Hygiene

- Test behaviour and state transitions, not implementation details.
- Clean up what a test installs (`addTearDown`).
- A bug fix comes with the test that would have caught it.
- Run the touched tests, then the whole suite, before reporting done; report unrelated failures
  instead of fixing them silently.
