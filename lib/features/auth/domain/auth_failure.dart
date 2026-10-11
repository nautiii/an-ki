/// Échec d'une opération d'authentification. Aucun texte ici : l'UI choisit
/// le message (`widgets/auth_failure_text.dart`).
enum AuthFailure implements Exception {
  // Refus de Firebase Auth, traduits par `AuthRepository`.
  weakPassword,
  emailAlreadyInUse,
  invalidEmail,
  userNotFound,
  wrongPassword,

  /// Refus de Firebase Auth sans cas dédié.
  unknown,

  // Autres échecs (réseau, plugin…), selon l'opération qui échoue.
  signUpFailed,
  signInFailed,
  googleSignInFailed,
  biometricFailed,

  /// Jeton d'empreinte refusé (retiré, remplacé ou d'un autre compte) : la
  /// session est fermée, il faut se reconnecter.
  biometricRevoked,
  signOutFailed,
  deleteAccountFailed,
}
