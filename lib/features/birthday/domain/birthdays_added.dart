/// Anniversaires que l'utilisateur vient d'ajouter sur cet appareil : un
/// import de contacts, ou une saisie à la main.
class const BirthdaysAdded({
  /// Nombre d'anniversaires ajoutés.
  required final int count,

  /// Venus de l'import des contacts ; sinon saisis à la main.
  required final bool imported,

  /// L'agenda était vide avant cet ajout : ce sont ses premiers
  /// anniversaires.
  required final bool first,
}) {
  @override
  bool operator ==(Object other) =>
      other is BirthdaysAdded &&
      other.count == count &&
      other.imported == imported &&
      other.first == first;

  @override
  int get hashCode => Object.hash(count, imported, first);
}
