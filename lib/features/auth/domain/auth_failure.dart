/// Échec d'une opération d'authentification. Aucun texte ici : l'UI choisit
/// le message (`widgets/auth_failure_text.dart`).
enum AuthFailure implements Exception {
  // Refus de Firebase Auth, traduits par `AuthRepository`.
  weakPassword,

  /// Adresse déjà celle d'un compte e-mail : à l'inscription, ou quand un
  /// invité se lie au compte Google de cette adresse.
  emailAlreadyInUse,

  /// Compte Google déjà connu d'AnKi : un invité ne peut pas s'y lier, mais
  /// peut l'ouvrir avec ses anniversaires (`AuthController.openGoogleAccount`).
  credentialAlreadyInUse,
  invalidEmail,
  userNotFound,
  wrongPassword,

  /// E-mail ou mot de passe refusé sans dire lequel : la protection contre
  /// l'énumération des e-mails, active par défaut sur les projets récents.
  invalidCredentials,

  /// Serveur injoignable : pas de réseau.
  network,

  /// Connexion sans réponse de Firebase dans le délai imparti
  /// (`AuthRepository.defaultSignInTimeout`) : réseau instable, ou service
  /// lent.
  signInTimeout,

  /// Trop d'essais d'affilée : Firebase bloque l'appareil un moment.
  tooManyRequests,

  /// Compte désactivé dans la console Firebase.
  userDisabled,

  /// Identité confirmée avec un autre compte Google que celui connecté.
  userMismatch,

  /// Opération sensible refusée à une connexion trop ancienne : l'identité
  /// doit être confirmée d'abord.
  requiresRecentLogin,

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
