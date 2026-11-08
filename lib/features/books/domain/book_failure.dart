/// Échec d'une opération sur les livres ; l'UI choisit le message.
enum BookFailure implements Exception {
  /// Quota quotidien de l'API Google Books dépassé (HTTP 429).
  quotaExceeded,

  /// Google Books injoignable : pas de réseau.
  network,

  /// Google Books a répondu une erreur ou une réponse illisible.
  unavailable,
}
