/// Échec de l'ouverture d'un compte Google avec les anniversaires d'un
/// invité (B5.5). Aucun texte ici : l'UI choisit le message.
enum GuestMergeFailure implements Exception {
  /// Pas de réseau avant la connexion : l'invité reste invité, rien n'a
  /// bougé.
  offline,

  /// Autre échec avant la connexion : l'invité reste invité.
  failed,

  /// La connexion a eu lieu, mais la reprise des anniversaires a échoué.
  incomplete,
}
