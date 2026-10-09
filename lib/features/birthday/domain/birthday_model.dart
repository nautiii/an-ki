import 'package:flutter/foundation.dart';

/// Anniversaire d'une personne : identité, date de naissance (année
/// comprise), catégories et photo éventuelle.
///
/// Modèle de domaine : Dart pur, immuable, sans Firebase ni Flutter UI. La
/// conversion Firestore (photo en base64 comprise) vit dans
/// `data/birthday_repository.dart`.
class const BirthdayModel({
  required final String id,
  required final String name,
  required final String surname,
  required final DateTime date,
  final List<String> categories = const [],

  /// Photo compressée (octets JPEG ou PNG), null sans photo.
  final Uint8List? picture,
}) {
  /// Copie modifiée. Un argument null signifie « inchangé » ; `clearPicture`
  /// retire la photo.
  BirthdayModel copyWith({
    String? name,
    String? surname,
    DateTime? date,
    List<String>? categories,
    Uint8List? picture,
    bool clearPicture = false,
  }) => BirthdayModel(
    id: id,
    name: name ?? this.name,
    surname: surname ?? this.surname,
    date: date ?? this.date,
    categories: categories ?? this.categories,
    picture: clearPicture ? null : picture ?? this.picture,
  );

  @override
  bool operator ==(Object other) =>
      other is BirthdayModel &&
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
