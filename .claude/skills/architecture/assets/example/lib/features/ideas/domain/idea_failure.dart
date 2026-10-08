/// Échecs métier des idées.
///
/// Levés par le dépôt ou le contrôleur, portés par `AsyncError`, traduits en
/// texte par l'UI (`widgets/idea_failure_text.dart`) : aucune chaîne ici.
enum IdeaFailure implements Exception {
  /// Titre vide ou trop long.
  invalidDraft,

  /// Plus de session : l'utilisateur s'est déconnecté entre-temps.
  signedOut,

  /// Écriture refusée ou impossible côté Firestore.
  storage,
}
