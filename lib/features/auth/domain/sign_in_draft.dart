/// Saisie de la connexion par e-mail, telle que tapée.
class const SignInDraft({
  required final String email,
  required final String password,
}) {
  /// Une adresse est tapée, hors espaces : de quoi envoyer le lien d'un mot
  /// de passe oublié.
  bool get hasEmail => email.trim().isNotEmpty;

  /// Règle de « Se connecter » : une adresse, hors espaces, et un mot de
  /// passe. Le formulaire l'applique à son bouton.
  bool get isValid => hasEmail && password.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is SignInDraft &&
      other.email == email &&
      other.password == password;

  @override
  int get hashCode => Object.hash(email, password);
}
