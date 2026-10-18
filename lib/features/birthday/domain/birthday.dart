import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:flutter/foundation.dart';

/// Anniversaire d'une personne : identité, date de naissance (année
/// facultative), catégories, photo éventuelle et années où il a été souhaité.
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

  /// Années dont l'anniversaire a été souhaité (`BirthdayWishes` dit
  /// laquelle compte aujourd'hui) ; l'historique reste.
  final List<int> wishedYears = const [],
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
      listEquals(other.picture, picture) &&
      listEquals(other.wishedYears, wishedYears);

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
    Object.hashAll(wishedYears),
  );
}
