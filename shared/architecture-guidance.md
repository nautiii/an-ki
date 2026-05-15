# Règles d'Architecture Core

Le projet suit une architecture en couches stricte, inspirée du Clean Architecture simplifié :

```
UI (Widgets / Screens)
 ↓
Provider (État & Logique UI - Riverpod)
 ↓
Repository (Abstraction des données / Business Logic)
 ↓
Service (Plugins / APIs externes / Firebase / Notifications)
 ↓
Data Sources (Firestore, Local Storage, API Google Books)
```

## Règles Strictes

* **Indépendance de l'UI** : L'UI ne doit JAMAIS accéder directement à Firebase ou aux plugins (ex: notifications). Elle passe par un Provider.
* **Logique Métier** : La logique complexe (calcul d'âge, tri, programmation de notifications) doit résider dans le Repository ou une extension de Modèle. L'UI ne doit JAMAIS contenir de logique métier.
* **Providers** : Ils sont l'UNIQUE source de l'état (state). Ils font le pont entre le Repository et l'UI. Ils gèrent l'état de chargement et d'erreur.
* **Repositories** : Ils gèrent TOUTES les interactions de données externes. Ils ne doivent pas dépendre de `BuildContext`.
* **Services** : Utilisés pour encapsuler des fonctionnalités transversales comme `NotificationService` ou `AuthService`.
* **Modèles** : Doivent être immuables (`final` fields), des objets Dart purs, et inclure :
    * `factory XModel.fromFirestore(DocumentSnapshot doc)`
    * `Map<String, dynamic> toJson()`
    * `XModel copyWith(...)`

## Gestion des Données & Firebase

* **Firestore** : Utiliser des `CollectionReference` typées avec `.withConverter`.
* **Temps réel** : Privilégier les Streams (`.snapshots()`) pour une UI toujours à jour.
* **Mapping** : Le mapping Firestore -> Modèle se fait dans le constructeur `fromFirestore` du modèle.

## Internationalisation (L10n)

* Utiliser `context.l10n` (généré par `flutter_gen`) pour TOUS les textes visibles dans l'UI.
* Les fichiers sources sont dans `lib/l10n/*.arb`.
* Ne jamais coder de chaînes de caractères en dur dans l'UI.

## Notifications Locales

* Encapsulées dans un `NotificationService`.
* Programmation basée sur le package `timezone` pour gérer les changements d'heure.
* Les IDs de notifications doivent être uniques et persistants (ex: hash de l'ID du document).

## Utilisation des Extensions

Les extensions sont essentielles pour garder le code propre et doivent être utilisées pour :
* **Mapping** : `String` → `Enum`.
* **Formatage** : `DateTime` → String localisée (via `intl`).
* **UI** : `Enum` → `IconData` ou `Color`.
* Éviter les classes utilitaires.

## Stratégie des Enums

Les enums sont des **objets intelligents**. Chaque enum DOIT :
* Avoir une méthode `fromId` ou équivalent pour le mapping Firestore.
* Exposer des propriétés UI (label, icône, couleur, priorité) via des getters ou extensions.
* AUCUN switch/case ne doit exister dans l'UI pour les enums.

## Nommage & Interdictions

* **Nommage Firestore** : Ne jamais changer le nom des collections ou des champs dans Firestore (ex: `user` vs `users`) car cela peut entraîner des comportements inattendus.
* **Imports** : Toujours utiliser des imports absolus (`package:an_ki/...`). Interdiction des imports relatifs.
* **Transformation** : Aucune transformation de données brute dans les widgets.

```dart
CollectionReference<UserModel> get _users =>
    _firestore.collection('user').withConverter<UserModel>(
      fromFirestore: (snapshot, _) => UserModel.fromFirestore(snapshot),
      toFirestore: (user, _) => user.toJson(),
    );
```
