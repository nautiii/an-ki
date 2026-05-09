# Global

## Anti-Patterns (À NE PAS FAIRE)

Vous devez éviter de générer :

* des appels Firebase à l'intérieur des widgets
* des widgets volumineux contenant de la logique
* de la logique de mapping répétée
* l'utilisation de `setState` pour des données globales
* des FutureBuilder / StreamBuilder imbriqués

Ne jamais ajouter l'`uid` à la méthode `updateBirthday`, car l'`uid` est déjà passé dans le constructeur de
la classe. Ceci afin de s'assurer que la méthode reste concentrée sur sa responsabilité principale, qui est
la mise à jour des informations d'anniversaire, sans se soucier de l'identification de l'utilisateur. En gardant
les paramètres de la méthode limités à ce qui est nécessaire pour sa fonctionnalité, nous favorisons un code plus propre et
réduisons le risque d'effets secondaires indésirables ou de confusion sur l'objectif de la méthode.
