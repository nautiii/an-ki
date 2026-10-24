import 'package:an_ki/features/birthday/domain/birthday.dart';

/// Catégorie d'anniversaire, présentée comme un groupe (« Famille »,
/// « Club de lecture »…) : un nom, une icône et parfois une teinte.
///
/// [name] est une clé pour les catégories prédéfinies (`family`…), traduite
/// par l'UI, ou le texte saisi pour un groupe créé par l'utilisateur.
/// [icon] est le point de code d'une icône Material. [tone] est l'indice de
/// la teinte choisie à la création, parmi les graines de `LabelTones` ; null
/// pour les catégories prédéfinies et les groupes créés avant ce choix.
///
/// Modèle de domaine : Dart pur, immuable. La conversion Firestore vit dans
/// `data/category_repository.dart`, le rendu (icône, couleur, libellé) dans
/// `widgets/category_display.dart`.
class const BirthdayCategory({
  required final String id,
  required final String name,
  required final int icon,
  final int? tone,
}) {
  @override
  bool operator ==(Object other) =>
      other is BirthdayCategory &&
      other.id == id &&
      other.name == name &&
      other.icon == icon &&
      other.tone == tone;

  @override
  int get hashCode => Object.hash(id, name, icon, tone);
}

/// Catégories d'un anniversaire.
extension BirthdayCategories on Birthday {
  /// Ses catégories parmi [known], dans l'ordre de la personne ; un id
  /// inconnu (catégorie supprimée, pas encore chargée) est ignoré.
  List<BirthdayCategory> categoriesFrom(Iterable<BirthdayCategory> known) {
    final byId = {for (final category in known) category.id: category};
    return [for (final id in categories) ?byId[id]];
  }
}
