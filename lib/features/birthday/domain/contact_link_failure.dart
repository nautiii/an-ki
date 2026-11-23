/// Échecs autour de la liaison d'une personne à son contact ; l'UI choisit
/// les mots.
enum ContactLinkFailure implements Exception {
  /// Le sélecteur de contacts du système ne s'est pas ouvert, ou n'a rien
  /// rendu de lisible.
  pickerUnavailable,

  /// La liaison n'a pas pu être enregistrée ou effacée sur ce téléphone.
  storageFailed,

  /// Aucune app ne compose le numéro, ou n'envoie de SMS.
  appUnavailable,
}
