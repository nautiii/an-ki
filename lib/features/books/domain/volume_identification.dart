import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/volume_guess.dart';

/// Un livre identifié par son ISBN : ce que les catalogues en savent, et sa
/// série devinée.
class const IdentifiedVolume({
  required final String isbn,
  required final BookMetadata metadata,

  /// Série et numéro ; null quand rien n'est sûr (« à classer »).
  final VolumeGuess? guess,
}) {
  @override
  bool operator ==(Object other) =>
      other is IdentifiedVolume &&
      other.isbn == isbn &&
      other.metadata == metadata &&
      other.guess == guess;

  @override
  int get hashCode => Object.hash(isbn, metadata, guess);
}

/// Identifie le livre [isbn] d'après les réponses de la BnF ([bnf]) et de
/// Google Books ([google]) ; null quand aucune ne le connaît.
///
/// Les réponses sont fusionnées (`mergeMetadata`), puis `guessVolume` passe
/// sur la fusion. Quand la BnF ne structure pas la série, la fusion peut perdre
/// ce que le titre de Google en disait (« Les Aventures de Tintin » +
/// « Tome 11 ») : la réponse de Google seule est aussi devinée, et la
/// meilleure confiance l'emporte (la fusion à égalité).
IdentifiedVolume? identifyVolume(
  String isbn, {
  BookMetadata? bnf,
  BookMetadata? google,
}) {
  final merged = mergeMetadata(bnf, google);
  if (merged == null) return null;
  var guess = guessVolume(merged);
  if (bnf?.seriesTitle == null && google != null && bnf != null) {
    final alone = guessVolume(google);
    if (alone != null &&
        (guess == null || alone.confidence.index > guess.confidence.index)) {
      guess = alone;
    }
  }
  return IdentifiedVolume(isbn: isbn, metadata: merged, guess: guess);
}
