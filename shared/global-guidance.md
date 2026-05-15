# Global - Anti-Patterns & Bonnes Pratiques

## Anti-Patterns (À NE PAS FAIRE)
* **Logique dans le Build** : Ne jamais instancier de contrôleurs, de repos ou lancer des futures dans la méthode `build`.
* **Appels Firebase UI** : Interdiction totale d'utiliser `FirebaseFirestore.instance` directement dans un Widget.
* **Widgets Obèses** : Un fichier widget ne devrait pas dépasser 200-300 lignes. Extraire systématiquement les sous-composants.
* **SetState Global** : Ne jamais utiliser `setState` pour des données qui doivent être partagées entre écrans. Utiliser Riverpod.
* **Hardcoded Strings** : Ne jamais utiliser de texte brut (Hardcoded). Utiliser `context.l10n`.
* **Logique de Mapping répétée** : Ne pas dupliquer la logique de transformation de données.
* **Nested Listeners** : Éviter les `StreamBuilder` ou `FutureBuilder` imbriqués. Préférer le pattern `AsyncValue` de Riverpod.

## Bonnes Pratiques (Senior Level)
* **Séparation des préoccupations** : Un Provider ne doit pas savoir *comment* les données sont récupérées (c'est le rôle du Repository).
* **Gestion d'Erreur** : Toujours prévoir un état d'erreur visuel et informatif pour chaque opération asynchrone.
* **Performance** : Utiliser des `ListView.builder` pour les listes potentiellement longues.
* **Clean Code** : "Si vous devez commenter une fonction, c'est qu'elle est mal nommée ou trop complexe."

## Règles Spécifiques au Domaine
**Mise à jour d'anniversaire** : Ne jamais ajouter l'`uid` à la méthode `updateBirthday`, car l'`uid` est déjà passé dans le constructeur de la classe Repository. Ceci afin de s'assurer que la méthode reste concentrée sur sa responsabilité principale, qui est la mise à jour des informations d'anniversaire, sans se soucier de l'identification de l'utilisateur. En gardant les paramètres de la méthode limités à ce qui est nécessaire pour sa fonctionnalité, nous favorisons un code plus propre et réduisons le risque d'effets secondaires indésirables ou de confusion sur l'objectif de la méthode.
