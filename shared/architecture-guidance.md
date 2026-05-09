# Règles d'Architecture Core

Le projet suit une architecture en couches stricte :

```
UI (Widgets)
 ↓
Provider (État)
 ↓
Repository (Accès aux données) / Services (Fonctionnalités externes)
 ↓
Firebase (Firestore) / Plugin Local
```

## Règles Strictes

* L'UI ne doit JAMAIS accéder directement à Firebase
* L'UI ne doit JAMAIS contenir de logique métier
* Les Providers sont l'UNIQUE source de l'état (state)
* Les Repositories gèrent TOUTES les interactions de données externes
* Les Modèles doivent être des objets Dart purs
* Utiliser `context.l10n` pour toutes les chaînes visibles dans l'UI

## Modèles

* Les modèles doivent être immuables
* Toujours fournir :
    * `factory XModel.fromFirestore(DocumentSnapshot doc)`
    * `Map<String, dynamic> toJson()`
    * `XModel copyWith(...)`

## Utilisation des Extensions

Les extensions doivent être utilisées pour :

* le mapping (String → Enum)
* le formatage (DateTime → affichage)
* l'enrichissement UI (Enum → icône/couleur)

Éviter les classes utilitaires.

## Stratégie des Enums

Les enums sont des **objets intelligents**, pas seulement des valeurs.
Chaque enum DOIT :

* faire le mapping depuis Firestore (String → Enum)
* exposer des propriétés UI via des extensions

Responsabilités d'exemple :

* label (étiquette)
* icône
* couleur
* priorité

AUCUN switch/case ne doit exister dans l'UI pour les enums.

## Nommage

Ne jamais changer le nom des collections ou des champs dans Firestore car cela peut entraîner des comportements inattendus.

```dart
CollectionReference<Map<String, dynamic>> get _users =>
    _firestore.collection('user'); // NE PAS RENOMMER EN 'users'
```

## Interdictions

* logique métier dans les widgets
* transformation de données dans les widgets
* imports relatifs (Toujours utiliser `package:an_ki/...`)
