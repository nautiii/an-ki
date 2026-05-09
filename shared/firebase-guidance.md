# Firebase

## Règles Firestore

* Toujours utiliser `.snapshots()` pour les fonctionnalités en temps réel
* Éviter `.get()` sauf si c'est strictement nécessaire
* Toujours mapper les données Firestore → Modèle
