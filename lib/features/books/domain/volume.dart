import 'package:flutter/foundation.dart';

/// Un tome que l'utilisateur possède, rangé ou non dans une série.
///
/// Modèle de domaine : Dart pur, immuable. Pour un tome scanné, [id] est son
/// ISBN : rescanner réécrit le même document.
class const Volume({
  required final String id,

  /// Série du tome ; null (ou numéro absent) : le tome est « à classer ».
  final String? seriesId,

  /// Numéro entier dans la série. Un « tome 10.5 », un hors-série ou un coffret
  /// n'en a pas : il reste à classer, avec son titre.
  final int? number,

  /// ISBN-13 normalisé (`normalizeIsbn`) ; null pour un tome ajouté à la main.
  final String? isbn,
  required final String title,
  required final List<String> authors,
  final String? imageUrl,
  final String? publisher,

  /// Date de parution telle que la source la donne (`2013`, `2013-06`,
  /// `2013-06-28`) : texte libre, jamais interprété par les règles.
  final String? publishedDate,

  /// Où en est la recherche des métadonnées de cet ISBN.
  required final LookupState lookup,
  required final DateTime addedAt,
}) {
  @override
  bool operator ==(Object other) =>
      other is Volume &&
      other.id == id &&
      other.seriesId == seriesId &&
      other.number == number &&
      other.isbn == isbn &&
      other.title == title &&
      listEquals(other.authors, authors) &&
      other.imageUrl == imageUrl &&
      other.publisher == publisher &&
      other.publishedDate == publishedDate &&
      other.lookup == lookup &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(
    id,
    seriesId,
    number,
    isbn,
    title,
    Object.hashAll(authors),
    imageUrl,
    publisher,
    publishedDate,
    lookup,
    addedAt,
  );
}

/// État de la recherche des métadonnées d'un ISBN scanné ; le nom est stocké
/// tel quel.
enum LookupState {
  /// Pas encore cherché (scan hors ligne, file d'attente).
  pending,

  /// Une source connaît ce livre.
  found,

  /// Aucune source ne le connaît : l'utilisateur le complète à la main.
  notFound,
}
