import 'package:flutter/foundation.dart';

/// Livre de la liste de l'utilisateur, ou résultat d'une recherche par ISBN
/// pas encore ajouté (alors [id] est vide et [scannedAt] null).
///
/// Modèle de domaine : Dart pur, immuable, sans Firebase ni Flutter UI. Les
/// conversions (Firestore, Google Books) vivent dans `data/book_repository.dart`.
class const Book({
  required final String id,
  required final String title,
  required final List<String> authors,
  required final String isbn,
  final String? imageUrl,
  final String? publishedDate,
  final String? description,
  final int? pageCount,
  final DateTime? scannedAt,
}) {
  @override
  bool operator ==(Object other) =>
      other is Book &&
      other.id == id &&
      other.title == title &&
      listEquals(other.authors, authors) &&
      other.isbn == isbn &&
      other.imageUrl == imageUrl &&
      other.publishedDate == publishedDate &&
      other.description == description &&
      other.pageCount == pageCount &&
      other.scannedAt == scannedAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    Object.hashAll(authors),
    isbn,
    imageUrl,
    publishedDate,
    description,
    pageCount,
    scannedAt,
  );
}
