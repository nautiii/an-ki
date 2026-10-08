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
  `test/features/<f>/<flow>_flow_test.dart`. Older tests sit one level higher
  (`test/features/birthday/repositories/`): new files follow the mirror.
- Shared fakes and helpers live in `test/support/`: reuse them, don't redefine them per file.
- Never touch real Firebase, network or platform channels. Use `FakeFirebaseFirestore`,
  `MockFirebaseAuth` (firebase_auth_mocks), `MockClient` (http), `mock_exceptions`, `mocktail`,
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
  use `overrideWith2` (`overrideWith` is deprecated since Riverpod 3.2). The `Fake…Notifier`
  classes in `test/support/` are legacy.
- **Widgets and screens**: `await tester.pumpHarness(widget, overrides: […])` (French locale,
  800×1200). A non-empty `overrides` list **replaces** `defaultTestOverrides`, it doesn't extend
  it. Pin async data with `xProvider.overrideWithValue(const AsyncData(…))`. Cover loading, empty,
  data and error; accessibility with `meetsGuideline(androidTapTargetGuideline)`,
  `meetsGuideline(labeledTapTargetGuideline)` and `find.bySemanticsLabel`.
- The harness keeps Riverpod's automatic retry until migration M0: test error states at provider
  level, or override the provider with a fixed `AsyncError`.
- `TestHarness` doesn't apply `AppTheme`: widget tests check behaviour; look and contrast are
  checked with the ux-ui snapshot tool.

## Hygiene

- Test behaviour and state transitions, not implementation details.
- Clean up what a test installs (`addTearDown`).
- A bug fix comes with the test that would have caught it.
- Run the touched tests, then the whole suite, before reporting done; report unrelated failures
  instead of fixing them silently.
