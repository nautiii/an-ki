import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:flutter/foundation.dart';

/// Anniversaire d'une personne : identité, date de naissance (année
/// facultative), catégories et photo éventuelle.
///
/// Modèle de domaine : Dart pur, immuable, sans Firebase ni Flutter UI. La
/// conversion Firestore (photo en base64 comprise) vit dans
/// `data/birthday_repository.dart`.
class const Birthday({
  required final String id,
  required final String name,
  required final String surname,
  required final BirthDate date,
  final List<String> categories = const [],

  /// Photo compressée (octets JPEG ou PNG), null sans photo.
  final Uint8List? picture,
}) {
  /// Prénom et nom réunis, sans espace de trop quand l'un manque
  /// (« Mamie »).
  String get fullName =>
      [name, surname].where((part) => part.isNotEmpty).join(' ');

  @override
  bool operator ==(Object other) =>
      other is Birthday &&
      other.id == id &&
      other.name == name &&
      other.surname == surname &&
      other.date == date &&
      listEquals(other.categories, categories) &&
      listEquals(other.picture, picture);

  // La photo ne contribue que par sa taille : hacher ses octets serait coûteux
  // et la taille suffit à rester cohérent avec ==.
  @override
  int get hashCode => Object.hash(
    id,
    name,
    surname,
    date,
    Object.hashAll(categories),
    picture?.length,
  );
}
