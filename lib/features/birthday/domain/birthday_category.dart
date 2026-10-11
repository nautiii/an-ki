/// Catégorie d'anniversaire (« famille », « sport »…) : un nom et une icône.
///
/// [name] est une clé pour les catégories prédéfinies (`family`…), traduite
/// par l'UI, ou le texte saisi pour une catégorie créée par l'utilisateur.
/// [icon] est le point de code d'une icône Material.
///
/// Modèle de domaine : Dart pur, immuable. La conversion Firestore vit dans
/// `data/category_repository.dart`, le rendu (icône, couleur, libellé) dans
/// `widgets/category_display.dart`.
class const BirthdayCategory({
  required final String id,
  required final String name,
  required final int icon,
}) {
  @override
  bool operator ==(Object other) =>
      other is BirthdayCategory &&
      other.id == id &&
      other.name == name &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(id, name, icon);
}
