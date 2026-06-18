# State Management (Riverpod 3)

* **Notifiers**: `Notifier<XState>` with a manual `XState` class is the established default.
  `AsyncNotifier` is allowed but not currently used. **Never `StateNotifier`.**
* **XState**: `final` fields, sensible defaults, `copyWith`. Granular flags (`isLoading`,
  `isCreating`,
  `errorMessage`) rather than one coarse boolean.
* **Dependencies**: access repositories/services via `ref.watch(xRepositoryProvider)` — never
  construct them.
* **Performance**: read with `ref.watch(p.select((s) => s.field))` to minimize rebuilds.
* **Logic**: business logic in Notifiers; computed/filtered views in derived `Provider`s.
* **Side effects**: methods return `bool`/`void`; UI reacts via `ref.listen` (navigation,
  snackbars).

## Async safety (mandatory)

* After every `await`, guard state writes with `if (ref.mounted)` — prevents writes on a disposed
  Notifier.
* Re-entrancy guard for one-shot actions: `if (state.isCreating) return;` before starting.
* Always `try/finally` so loading flags reset even on error.
* Streams: keep the `StreamSubscription` on the Notifier, cancel & re-subscribe in the start method,
  and cancel it in `ref.onDispose`.

## Derived state

```dart

final filteredBirthdaysProvider = Provider<List<BirthdayModel>>((ref) {
  final all = ref.watch(birthdaysListProvider);
  final query = ref.watch(birthdaySearchProvider).toLowerCase();
  return all.where((b) => b.name.toLowerCase().contains(query)).toList();
});
```

## Error mapping (auth pattern)

Catch `FirebaseAuthException`, map `e.code` → localized message via a private
`_getErrorMessage(code, l10n)`,
store it in `state.errorMessage`, and return `bool` for the UI to react.
