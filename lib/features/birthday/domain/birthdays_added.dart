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

  /// Prénom et nom de la personne saisie à la main, pour la nommer ; null
  /// pour un import, qui se compte.
  final String? name,

  /// Id de l'anniversaire saisi à la main, pour ouvrir sa page ; null pour
  /// un import.
  final String? id,
}) {
  @override
  bool operator ==(Object other) =>
      other is BirthdaysAdded &&
      other.count == count &&
      other.imported == imported &&
      other.first == first &&
      other.name == name &&
      other.id == id;

  @override
  int get hashCode => Object.hash(count, imported, first, name, id);
}
