/// Échec d'un import de contacts ; l'UI choisit le message.
enum ContactImportFailure implements Exception {
  /// L'utilisateur a refusé l'accès aux contacts ; la boîte système peut
  /// encore être proposée.
  permissionDenied,

  /// Accès refusé pour de bon : seuls les réglages de l'app l'accordent.
  permissionBlocked,

  /// Lecture du répertoire impossible (erreur du plugin).
  unreadable,
}
