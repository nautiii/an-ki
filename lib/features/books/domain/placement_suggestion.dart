import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/series_key.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_guess.dart';
import 'package:an_ki/features/books/domain/volume_placement.dart';

/// Où « À classer » propose de ranger un tome : une série existante, ou une
/// nouvelle à créer. Une proposition, jamais appliquée seule : l'utilisateur
/// l'accepte d'un toucher, ou choisit une autre série.
class const PlacementSuggestion({
  /// Série existante ; null : une nouvelle série nommée [seriesName].
  final Series? series,

  /// Nom de la série : celui de [series], ou celui de la série à créer.
  required final String seriesName,

  /// Numéro proposé pour le tome.
  required final int number,
}) {
  /// Vrai quand la série est à créer.
  bool get isNew => series == null;

  @override
  bool operator ==(Object other) =>
      other is PlacementSuggestion &&
      other.series == series &&
      other.seriesName == seriesName &&
      other.number == number;

  @override
  int get hashCode => Object.hash(series, seriesName, number);
}

/// La meilleure supposition pour ranger [volume] parmi [entries], même
/// incertaine ; null quand le tome n'a pas de titre ou qu'il sort de la
/// numérotation (coffret, hors-série, « Tome 10.5 » : [isOutsideNumbering]).
///
/// 1. Une devinette sur le titre (`guessVolume`), quelle que soit sa
///    confiance : la série qui porte la clé de son nom, sinon une nouvelle
///    série de ce nom, au numéro deviné.
/// 2. Sinon le titre sans son sous-titre (« Le Petit Prince : … ») sert de
///    nom : la série qui porte sa clé, au prochain tome à acheter (sinon le
///    suivant du dernier), ou une nouvelle série dont il est le tome 1.
PlacementSuggestion? suggestPlacement(Volume volume, List<ShelfEntry> entries) {
  final series = [for (final entry in entries) entry.series];
  final guess = guessVolume(
    BookMetadata(
      title: volume.title,
      authors: volume.authors,
      publisher: volume.publisher,
    ),
  );
  if (guess != null) {
    final key = seriesKey(guess.seriesName);
    if (key.isNotEmpty) {
      final existing = findSeriesByKey(series, key);
      return PlacementSuggestion(
        series: existing,
        seriesName: existing?.name ?? guess.seriesName.trim(),
        number: guess.number,
      );
    }
  }

  if (isOutsideNumbering(volume.title)) return null;
  final name = _withoutSubtitle(volume.title);
  final key = seriesKey(name);
  if (key.isEmpty) return null;
  final existing = findSeriesByKey(series, key);
  if (existing == null) {
    return PlacementSuggestion(seriesName: name, number: 1);
  }
  final entry = entries.firstWhere((entry) => entry.series.id == existing.id);
  return PlacementSuggestion(
    series: existing,
    seriesName: existing.name,
    number: entry.nextToBuy ?? (entry.last ?? 0) + 1,
  );
}

/// Le titre avant son sous-titre : `volumeTitleOf` les joint par « : ».
String _withoutSubtitle(String title) {
  final cut = title.indexOf(' : ');
  return (cut < 0 ? title : title.substring(0, cut)).trim();
}
