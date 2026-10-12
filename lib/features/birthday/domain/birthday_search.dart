import 'package:an_ki/features/birthday/domain/birthday.dart';

/// Règle de recherche sur une liste d'anniversaires.
extension BirthdaySearch on Iterable<Birthday> {
  /// Anniversaires dont le prénom, le nom ou le nom complet contient [query]
  /// (sans tenir compte de la casse) et qui portent toutes les catégories de
  /// [categoryIds]. Un texte vide garde tout le monde.
  List<Birthday> matching(String query, {List<String> categoryIds = const []}) {
    final needle = query.trim().toLowerCase();
    return [
      for (final birthday in this)
        if (categoryIds.every(birthday.categories.contains) &&
            birthday.fullName.toLowerCase().contains(needle))
          birthday,
    ];
  }
}
