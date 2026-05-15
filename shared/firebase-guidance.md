# Firebase (Firestore, Auth, Storage)

## Firestore : Structure & Accès
* **Mapping Typé** : Toujours utiliser `.withConverter<T>` pour transformer les documents Firestore en objets de domaine.
* **Streams vs Futures** : Privilégier `.snapshots()` pour une synchronisation automatique de l'UI. Utiliser `.get()` uniquement pour les opérations ponctuelles ou de migration.
* **Sécurité** : Ne jamais inclure de logique de filtrage basée sur l'UID dans le Repository si elle peut être gérée par les `Firestore Rules`. Cependant, passer systématiquement l'UID dans les requêtes pour l'isolation.
* **Performance** : Utiliser des index composites pour les requêtes complexes (ex: filtrage + tri).

## Authentification
* **Anonyme vers Permanent** : Gérer le "linking" de compte pour permettre aux utilisateurs invités de sauvegarder leurs données sans perte.
* **État d'Auth** : Utiliser un `StreamProvider` pour écouter `authStateChanges()` et réagir immédiatement aux déconnexions.

## Storage
* **Optimisation** : Toujours compresser les images avant l'upload via `image_picker` ou un plugin de compression.
* **Structure** : Organiser les fichiers par UID (ex: `users/{uid}/avatars/{filename}`).

## Bonnes Pratiques
* **Offline Persistence** : Activer la persistance hors ligne de Firestore pour une meilleure expérience utilisateur.
* **Transactions** : Utiliser des `runTransaction` ou `WriteBatch` pour les opérations atomiques impliquant plusieurs documents.
