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
  signOutFailed,
  deleteAccountFailed,
}
