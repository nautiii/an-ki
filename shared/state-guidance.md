# State Management (Riverpod 3)

## Usage Rules
* **Notifiers**: Use `Notifier` with custom state classes or `AsyncNotifier`. **No StateNotifier.**
* **Performance**: Always use `.select()` in `ref.watch` to minimize rebuilds.
* **Logic Location**: Business logic belongs in Notifiers. Transformations in derived Providers.
* **Side Effects**: Use `ref.listen` for navigation or snackbars.
* **Lifecycle**: Use `ref.onDispose` to cancel subscriptions or dispose controllers.

## Patterns
* **Manual State**: Define an `XState` class with `isLoading`, `errorMessage`, and `copyWith`.
* **AsyncValue**: Use `.when` or `.maybeWhen` in UI when using `AsyncNotifier`.
* **Side Effects in Notifier**: Return `bool` or `void` from methods. UI handles feedback based on state or returned value.
* **Derived State**:
```dart
final filteredItemsProvider = Provider((ref) {
  final state = ref.watch(itemsProvider);
  final items = state.items;
  final filter = ref.watch(filterProvider);
  return items.where((i) => i.matches(filter)).toList();
});
```
