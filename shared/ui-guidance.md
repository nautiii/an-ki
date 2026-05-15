# Guide UX/UI (Niveau Senior)

## Grille & Espacement
* **8dp Grid** : Utiliser des multiples de 8 pour les marges et les paddings (`8.0`, `16.0`, `24.0`, `32.0`).
* **Consistance** : Utiliser `SizedBox(height: 16)` ou `Gap(16)` pour séparer les éléments verticaux.

## Mise en page & Feedback
* **Feedback visuel** : Utiliser des `SnackBar` flottantes avec `behavior: SnackBarBehavior.floating` et des bords arrondis.
* **Haptic Feedback** : Déclencher un retour haptique léger (`HapticFeedback.lightImpact()`) lors d'actions réussies ou de pressions sur des boutons importants.
* **Transitions** : Utiliser `AnimatedSwitcher` pour les changements d'icônes ou d'états simples.
* **Empty States** : Ne jamais laisser un écran vide. Afficher une illustration minimaliste ou une icône avec un texte d'explication et un bouton d'action (CTA) si pertinent.

## Widgets Complexes
* **Dismissible (Swipe)** :
    * Toujours entourer d'un `ClipRRect` si la tuile est arrondie pour éviter que le background ne dépasse pendant le swipe.
    * Le `Container` enfant ne doit PAS avoir de `borderRadius` propre si un `ClipRRect` parent gère la découpe globale.
    * Préférer la direction `startToEnd` pour la suppression (naturel pour les droitiers).
* **Skeleton Loading** : Utiliser des shimmers (`Shimmer.fromColors`) pour les états de chargement des listes afin de réduire la charge cognitive perçue.

## Material 3 & Style
* **Couleurs** : Utiliser exclusivement `colorScheme.surfaceContainerHigh` ou `surfaceContainerHighest` pour les cartes au lieu de `Card` avec élévation, pour un look moderne et plat.
* **Iconographie** : Préférer les variantes `rounded` ou `outline` des `Icons` pour une cohérence visuelle.
* **Boutons** : 
    * `ElevatedButton` pour les actions principales.
    * `FilledButton.tonal` pour les actions secondaires.
    * `TextButton` pour les actions tertiaires ou discrètes.
* **Typography** : Utiliser les rôles Material 3 (`display`, `headline`, `title`, `body`, `label`) via `Theme.of(context).textTheme`.

## Interactions
* **Validation** : Afficher les erreurs en temps réel sur les champs de saisie (`TextField.decoration.errorText`).
* **Scroll** : Toujours utiliser `AlwaysScrollableScrollPhysics` sur les listes rafraîchissables (`RefreshIndicator`) pour garantir que le rebond fonctionne même sur les listes courtes.
