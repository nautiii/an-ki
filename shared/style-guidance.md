# Guide de Style

## Style de Code Attendu

Vous devez générer un code qui est :

* modulaire
* fortement typé
* "null-safe" (sécurité nulle)
* facilement testable

## Règles UI

* Utiliser Material 3 (`useMaterial3: true`)
* Utiliser `ColorScheme` (pas de couleurs codées en dur)
* L'UI doit être "dumb" (chargée uniquement du rendu)
* Préférer les constructeurs `const` quand c'est possible

## Conventions de Nommage

* Modèles : `XModel`
* Répertoires (Repositories) : `XRepository`
* Fournisseurs (Providers) : `XProvider`
* Widgets : descriptifs et axés sur l'UI

## Importation de fichiers

* Toujours utiliser des imports absolus (`package:an_ki/**.dart`).
* Ne jamais utiliser d'imports relatifs pour des fichiers au sein du même package.

## Exemple de Structure de Code

```dart
// lib/features/feature_name/providers/feature_provider.dart
class FeatureState {
  final List<ItemModel> items;
  final bool isLoading;

  FeatureState({required this.items, this.isLoading = false});

  FeatureState copyWith({List<ItemModel>? items, bool? isLoading}) =>
      FeatureState(items: items ?? this.items, isLoading: isLoading ?? this.isLoading);
}

class FeatureNotifier extends Notifier<FeatureState> {
  @override
  FeatureState build() => FeatureState(items: []);

// Logique ici
}
```
