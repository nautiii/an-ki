/// Échec d'un import de contacts ; l'UI choisit le message.
enum ContactImportFailure implements Exception {
  /// L'utilisateur a refusé l'accès aux contacts.
  permissionDenied,
}
