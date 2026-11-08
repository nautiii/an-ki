/// Longueur maximale d'un message de vœu personnalisé, en caractères visibles
/// : le champ de saisie la fait respecter.
const wishMessageMaxLength = 500;

/// Message de vœu personnalisé à enregistrer à partir de la saisie [input] :
/// sans espaces autour, ou null — le message par défaut — quand il est vide
/// ou identique à [defaultMessage], espaces mis à part (une espace ordinaire
/// tapée au lieu de l'insécable). Revenir au défaut le laisse suivre les
/// changements du texte par défaut et son variant du lendemain.
String? customWishMessage(String input, {required String defaultMessage}) {
  final message = input.trim();
  if (message.isEmpty || _spaced(message) == _spaced(defaultMessage)) {
    return null;
  }
  return message;
}

/// [text] aux espaces réduites à une seule, ordinaire (`\s` couvre U+00A0).
String _spaced(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');
