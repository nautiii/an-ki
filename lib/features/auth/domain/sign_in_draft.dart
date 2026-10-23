/// Saisie de la connexion par e-mail, telle que tapée.
class const SignInDraft({
  required final String email,
  required final String password,
}) {
  /// Règle de « Se connecter » : une adresse, hors espaces, et un mot de
  /// passe. Le formulaire l'applique à son bouton.
  bool get isValid => email.trim().isNotEmpty && password.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is SignInDraft &&
      other.email == email &&
      other.password == password;

  @override
  int get hashCode => Object.hash(email, password);
}
