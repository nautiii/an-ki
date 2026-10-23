/// Saisie de l'inscription par e-mail, telle que tapée : le mot de passe et
/// sa [confirmation].
class const SignUpDraft({
  required final String name,
  required final String surname,
  required final String email,
  required final String password,
  required final String confirmation,
}) {
  /// Règle de « S'inscrire » : prénom, nom et adresse remplis (hors
  /// espaces), deux fois le même mot de passe. Le formulaire l'applique à son
  /// bouton.
  bool get isValid =>
      name.trim().isNotEmpty &&
      surname.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      password.isNotEmpty &&
      confirmation == password;

  /// La confirmation est à signaler comme différente du mot de passe. Pendant
  /// sa frappe ([typing]), seulement quand elle ne peut plus le devenir : une
  /// confirmation juste mais inachevée ne dit rien.
  bool confirmationDiffers({required bool typing}) =>
      confirmation.isNotEmpty &&
      (typing ? !password.startsWith(confirmation) : confirmation != password);

  @override
  bool operator ==(Object other) =>
      other is SignUpDraft &&
      other.name == name &&
      other.surname == surname &&
      other.email == email &&
      other.password == password &&
      other.confirmation == confirmation;

  @override
  int get hashCode => Object.hash(name, surname, email, password, confirmation);
}
