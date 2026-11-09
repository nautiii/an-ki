/// Échec d'une opération sur l'étagère (séries et tomes dans Firestore) ;
/// l'UI choisit le message. Les catalogues (BnF, Google Books) lèvent
/// `BookFailure`.
enum ShelfFailure implements Exception {
  /// Lecture sur le serveur impossible : hors ligne, ou serveur injoignable.
  offline,

  /// Refusé par les règles Firestore (session expirée, règles pas encore
  /// déployées).
  denied,

  /// Le code lu n'est pas un ISBN valide (clé de contrôle fausse).
  invalidIsbn,

  /// Toute autre erreur de Firestore.
  failed,
}
