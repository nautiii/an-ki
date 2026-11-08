import 'package:an_ki/features/books/domain/series_key.dart';
import 'package:flutter/foundation.dart';

/// Ce qu'un catalogue (BnF, Google Books) sait d'un livre à partir de son
/// ISBN.
///
/// Ni description ni résumé : trop lourds, et les CGU de Google interdisent
/// d'en garder une copie.
class const BookMetadata({
  required final String title,
  final String? subtitle,
  required final List<String> authors,
  final String? publisher,

  /// Date de parution telle que la source la donne (`2013`, `2013-06-28`).
  final String? publishedDate,
  final String? imageUrl,

  /// Titre de la série quand la source le structure (BnF 225/461), sans le
  /// numéro.
  final String? seriesTitle,

  /// Numéro du tome dans la série, quand la source le structure et qu'il est
  /// entier.
  final int? seriesNumber,
}) {
  @override
  bool operator ==(Object other) =>
      other is BookMetadata &&
      other.title == title &&
      other.subtitle == subtitle &&
      listEquals(other.authors, authors) &&
      other.publisher == publisher &&
      other.publishedDate == publishedDate &&
      other.imageUrl == imageUrl &&
      other.seriesTitle == seriesTitle &&
      other.seriesNumber == seriesNumber;

  @override
  int get hashCode => Object.hash(
    title,
    subtitle,
    Object.hashAll(authors),
    publisher,
    publishedDate,
    imageUrl,
    seriesTitle,
    seriesNumber,
  );
}

/// Fusionne ce que la BnF et Google Books savent d'un même ISBN ; null quand
/// aucune des deux ne le connaît.
///
/// - Série, numéro, titre, sous-titre, éditeur et auteurs : la BnF d'abord
///   (notices catalographiques), Google pour ce qui lui manque. La série et son
///   numéro vont ensemble, le titre et son sous-titre aussi : jamais un champ
///   de l'une complétant l'autre à contresens. Quand les titres diffèrent et
///   que la BnF n'a pas de série, ce que Google dit du titre (« Les Aventures
///   de Tintin » + « Tome 11 ») se perd : l'appelant peut aussi passer
///   `guessVolume` sur la réponse de Google seule.
/// - Couverture : Google (la BnF n'en donne pas).
/// - Date de parution : celle de la BnF, sauf si Google la donne plus précise
///   pour la même année (la BnF n'a souvent que l'année).
BookMetadata? mergeMetadata(BookMetadata? bnf, BookMetadata? google) {
  if (bnf == null) return google;
  if (google == null) return bnf;

  final useBnfSeries = bnf.seriesTitle != null;
  final authors = bnf.authors.isNotEmpty ? bnf.authors : google.authors;
  // Le sous-titre de Google complète le titre de Google, pas celui de la BnF :
  // « Le secret de la Licorne » + « Tome 11 : … » (Google, titre « Les
  // Aventures de Tintin ») ferait de ce titre une série. Il ne passe que si les
  // deux titres disent la même chose.
  final sameTitle =
      bnf.title.isEmpty || seriesKey(bnf.title) == seriesKey(google.title);
  return BookMetadata(
    title: bnf.title.isNotEmpty ? bnf.title : google.title,
    subtitle: bnf.subtitle ?? (sameTitle ? google.subtitle : null),
    authors: authors,
    publisher: bnf.publisher ?? google.publisher,
    publishedDate: _morePrecise(bnf.publishedDate, google.publishedDate),
    imageUrl: google.imageUrl ?? bnf.imageUrl,
    seriesTitle: useBnfSeries ? bnf.seriesTitle : google.seriesTitle,
    seriesNumber: useBnfSeries ? bnf.seriesNumber : google.seriesNumber,
  );
}

/// [bnf], sauf si [google] la précise pour la même année (`2013` → `2013-06`).
String? _morePrecise(String? bnf, String? google) {
  if (bnf == null) return google;
  if (google != null && google.length > bnf.length && google.startsWith(bnf)) {
    return google;
  }
  return bnf;
}
