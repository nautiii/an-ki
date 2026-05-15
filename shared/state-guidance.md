# Gestion de l'État (Riverpod 3)

## Règles d'Utilisation

* **Performance** : Toujours utiliser `.select((s) => s.field)` lors du `ref.watch` pour éviter les reconstructions inutiles du widget si d'autres champs de l'état changent.
* **Notifier** : Utiliser `Notifier` pour l'état synchrone et `AsyncNotifier` pour l'asynchrone. **`StateNotifier` est strictement interdit.**
* **Emplacement de la Logique** : Toute la logique de transformation de données ou de filtrage doit résider dans le `Notifier` (ex: via un provider filtré) ou dans le Repository.
* **Ref.listen** : Utiliser `ref.listen` pour les effets de bord (navigation, SnackBars) en réaction à un changement d'état.
* **Initialisation** : Utiliser `ref.onDispose` pour fermer les streams, les timers ou les contrôleurs.

## Patterns

### Pattern de sélection (Optimisation)
```dart
// Dans le widget : Re-build uniquement si 'items' change
final items = ref.watch(myProvider.select((s) => s.items));
```

### AsyncNotifier Pattern
Gérer les chargements et erreurs de manière standardisée avec `AsyncValue.guard` :
```dart
class MyNotifier extends AsyncNotifier<List<Data>> {
  @override
  FutureOr<List<Data>> build() async {
    // Initialisation asynchrone
    return ref.read(repositoryProvider).getData();
  }

  Future<void> addItem(Data item) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(repositoryProvider).add(item);
      return ref.read(repositoryProvider).getData(); // Rafraîchir les données
    });
  }
}
```

### UI Consumption (AsyncValue)
Toujours utiliser `.when` ou `.maybeWhen` pour garantir que tous les états (data, loading, error) sont gérés :
```dart
final asyncData = ref.watch(myProvider);

return asyncData.when(
  data: (data) => MyListView(data: data),
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (err, stack) => MyErrorWidget(err, stack),
);
```

### Provider Filtering
Créer des providers dérivés pour la logique de filtrage ou de tri afin de garder les widgets "dumb" :
```dart
final filteredItemsProvider = Provider<List<Item>>((ref) {
  final items = ref.watch(itemsProvider).value ?? [];
  final filter = ref.watch(filterProvider);
  return items.where((item) => item.type == filter).toList();
});
```
