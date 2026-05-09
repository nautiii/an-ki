# State Management (Riverpod 3)

## Usage Rules

* **Performance**: Toujours utiliser `.select((s) => s.field)` lors du `ref.watch` pour éviter les
  reconstructions inutiles du widget si d'autres champs de l'état changent.
* **Notifier**: Préférer `Notifier` (synchrone) ou `AsyncNotifier` (asynchrone). `StateNotifier` est
  strictement interdit.
* **Logic Location**: Toute la logique de transformation de données doit résider dans le `Notifier`,
  pas dans l'UI.
* **Initialization**: Utiliser `ref.onDispose` pour nettoyer les streams ou les contrôleurs.

## Patterns

### Pattern de sélection (Optimization)

```dart
// Dans le widget : Re-build uniquement si 'items' change
final items = ref.watch(myProvider.select((s) => s.items));
```

### AsyncNotifier Pattern

```dart
class MyNotifier extends AsyncNotifier<List<Data>> {
  @override
  FutureOr<List<Data>> build() async {
    return _fetchInitialData();
  }

  Future<void> addItem(Data item) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repository.add(item));
  }
}
```
