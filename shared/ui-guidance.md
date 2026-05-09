# Guide UX/UI (Niveau Senior)

## Mise en page & Feedback

* **Feedback visuel** : Utiliser des `SnackBar` flottantes avec
  `behavior: SnackBarBehavior.floating`.
* **Transitions** : Utiliser `AnimatedSwitcher` pour les changements d'icônes ou d'états simples.

## Widgets Complexes

* **Dismissible (Swipe)** :
    * Toujours entourer d'un `ClipRRect` si la tuile est arrondie pour éviter que le background ne
      dépasse pendant le swipe.
    * Le `Container` enfant ne doit PAS avoir de `borderRadius` propre si un `ClipRRect` parent gère
      la découpe globale.
    * Préférer la direction `startToEnd` pour la suppression (naturel pour les droitiers).

## Material 3

* Utiliser `surfaceContainerHigh` ou `surfaceContainerHighest` pour les cartes au lieu de `Card`
  avec élévation, pour un look moderne et plat.
