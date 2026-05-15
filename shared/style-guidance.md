# Guide de Style

## Style de Code Attendu
* **Modularité** : Diviser les grands widgets en petits sous-widgets privés (`_MySubWidget`) pour plus de clarté.
* **Forte Typage** : Éviter `dynamic`. Toujours typer les listes, maps et futurs.
* **Null-Safety** : Utiliser les opérateurs `?` et `!` avec parcimonie. Préférer les valeurs par défaut ou les contrôles de nullité explicites.
* **Const** : Utiliser `const` partout où c'est possible pour optimiser le rendu.
* **Testabilité** : Le code doit être facilement testable par isolation des couches.

## Règles UI & Material 3
* **Material 3** : Utiliser exclusivement Material 3 (`useMaterial3: true`).
* **Couleurs** : Utiliser `ColorScheme` (pas de couleurs codées en dur).
* **UI Dumb** : L'UI doit être "dumb", uniquement chargée du rendu et sans logique métier.

## Conventions de Nommage
* **Fichiers** : `snake_case.dart`.
* **Classes** : `PascalCase`.
* **Modèles** : `XModel`.
* **Repositories** : `XRepository`.
* **Providers** : `xProvider` (camelCase pour l'instance globale).
* **Screens** : `XScreen`.

## Importation de fichiers
* Toujours utiliser des imports absolus (`package:an_ki/**.dart`).
* **Ordre des imports** :
  1. Flutter/Dart core
  2. Packages tiers
  3. Imports internes au projet

## Modèles & Immuabilité
* Utiliser `final` pour tous les champs de classe.
* Implémenter `copyWith` pour faciliter les mises à jour d'état.
* Éviter les logiques complexes dans les constructeurs.

## Exemple de Structure de Code

```dart
// lib/features/user/providers/user_provider.dart
class UserState {
  final UserModel? user;
  final bool isLoading;

  UserState({this.user, this.isLoading = false});

  UserState copyWith({UserModel? user, bool? isLoading}) =>
      UserState(user: user ?? this.user, isLoading: isLoading ?? this.isLoading);
}

class UserNotifier extends Notifier<UserState> {
  @override
  UserState build() => UserState();

  void updateName(String name) {
    // Logique ici via repository
  }
}
```
