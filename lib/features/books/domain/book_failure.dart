/// Échec d'une opération sur les livres ; l'UI choisit le message.
///
/// Partagé par les catalogues (BnF, Google Books) : une même cause se lit pareil
/// quelle que soit la source.
enum BookFailure implements Exception {
  /// Quota quotidien de l'API Google Books dépassé (HTTP 429). La BnF n'a pas
  /// de quota : elle ne lève jamais celui-ci.
  quotaExceeded,

  /// Catalogue injoignable : pas de réseau, ou délai dépassé.
  network,

  /// Le catalogue a répondu une erreur, ou une réponse illisible.
  unavailable,
}
