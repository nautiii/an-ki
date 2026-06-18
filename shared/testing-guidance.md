# Testing

Every new or changed feature ships with tests. Target: **100% meaningful coverage**.
"If it's not testable, the architecture is likely wrong."

## Layout

`test/` mirrors `lib/` exactly:

```
test/
├── core/{extensions,providers,services}/...
├── features/<feature>/
│   ├── models/        # X_model_test.dart
│   ├── repositories/  # X_repository_test.dart (fake Firestore)
│   ├── <feature>_notifier_test.dart
│   └── <flow>_test.dart   # widget / flow tests
└── support/           # shared fakes & harness
```

## Layers to cover

* **Models**: `fromFirestore` ↔ `toJson` round-trip, `copyWith`, null/optional handling.
* **Repositories**: inject `fake_cloud_firestore`; assert `uid` isolation, `WriteBatch` deletes,
  base64 image write.
* **Notifiers**: drive with a `ProviderContainer` + repository override; assert state transitions,
  no widget overhead.
* **UI/flows**: widget tests via the shared harness; assert rendered state, validation, empty
  states.

## Tooling

* **Fakes** live in `test/support/` (`fake_providers.dart`): `FakeXRepository`, `FakeXNotifier`,
  `defaultTestOverrides`. Reuse them — don't redefine per test.
* **Harness** (`test_harness.dart`): `tester.pumpHarness(widget, overrides: [...])` wires
  `ProviderScope`
    + `MaterialApp` + localization. Use it for all widget tests.
* **Libs**: `fake_cloud_firestore`, `firebase_auth_mocks`, `mocktail`, `mock_exceptions`.

## Patterns

* Override providers, never reach real Firebase. `addTearDown(container.dispose)` always.
* Test behaviour and state transitions, not implementation details.
* See `memory/testing-strategy.md` for coverage conventions (`coverage:ignore`).
