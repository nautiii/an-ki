/// Saisie de l'inscription par e-mail, telle que tapée. Le mot de passe ne se
/// tape qu'une fois : son œil le montre, et le lien du mot de passe oublié
/// rattrape une faute de frappe.
class const SignUpDraft({
  required final String name,
  required final String surname,
  required final String email,
  required final String password,
}) {
  /// Règle de « S'inscrire » : prénom, nom et adresse remplis (hors
  /// espaces), un mot de passe. Le formulaire l'applique à son bouton.
  bool get isValid =>
      name.trim().isNotEmpty &&
      surname.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      password.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is SignUpDraft &&
      other.name == name &&
      other.surname == surname &&
      other.email == email &&
      other.password == password;

  @override
  int get hashCode => Object.hash(name, surname, email, password);
}
