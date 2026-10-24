/// Échec d'une opération d'authentification. Aucun texte ici : l'UI choisit
/// le message (`widgets/auth_failure_text.dart`).
enum AuthFailure implements Exception {
  // Refus de Firebase Auth, traduits par `AuthRepository`.
  weakPassword,
  emailAlreadyInUse,

  /// Compte Google déjà connu d'AnKi (lié à un autre compte, ou son adresse
  /// est celle d'un compte e-mail) : un invité ne peut pas s'y lier.
  credentialAlreadyInUse,
  invalidEmail,
  userNotFound,
  wrongPassword,

  /// E-mail ou mot de passe refusé sans dire lequel : la protection contre
  /// l'énumération des e-mails, active par défaut sur les projets récents.
  invalidCredentials,

  /// Serveur injoignable : pas de réseau.
  network,

  /// Refus de Firebase Auth sans cas dédié.
  unknown,

  // Autres échecs (réseau, plugin…), selon l'opération qui échoue.
  signUpFailed,
  signInFailed,
  passwordResetFailed,
  googleSignInFailed,
  biometricFailed,

  /// Jeton d'empreinte refusé (retiré, remplacé ou d'un autre compte) : la
  /// session est fermée, il faut se reconnecter.
  biometricRevoked,
  signOutFailed,
  deleteAccountFailed,
}
