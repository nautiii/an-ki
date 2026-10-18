/// Échec d'un vœu envoyé depuis AnKi ; l'UI choisit les mots.
enum WishFailure implements Exception {
  /// La feuille de partage du système n'a pas pu s'ouvrir.
  shareUnavailable,
}
