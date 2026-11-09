import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/series_key.dart';
import 'package:an_ki/features/books/domain/volume_guess.dart';

/// Où ranger un tome deviné : une série existante, ou une nouvelle à créer.
class const VolumePlacement({
  required final Series series,

  /// Vrai quand [series] n'existe pas encore : l'appelant la crée.
  required final bool isNew,

  /// Numéro du tome dans [series].
  required final int number,
}) {
  @override
  bool operator ==(Object other) =>
      other is VolumePlacement &&
      other.series == series &&
      other.isNew == isNew &&
      other.number == number;

  @override
  int get hashCode => Object.hash(series, isNew, number);
}

/// Range le tome deviné par [guess] : dans la série de [series] qui porte la
/// clé de son nom ([findSeriesByKey]), sinon dans une nouvelle série nommée
/// d'après lui, d'id [newSeriesId]. Null quand rien n'est sûr ([guess] absent
/// ou de confiance basse) : le tome reste « à classer ».
VolumePlacement? placeVolume(
  VolumeGuess? guess,
  List<Series> series, {
  required String Function() newSeriesId,
}) {
  if (guess == null || guess.confidence == GuessConfidence.low) return null;
  final key = seriesKey(guess.seriesName);
  if (key.isEmpty) return null;
  final existing = findSeriesByKey(series, key);
  if (existing != null) {
    return VolumePlacement(
      series: existing,
      isNew: false,
      number: guess.number,
    );
  }
  return VolumePlacement(
    series: Series(
      id: newSeriesId(),
      name: guess.seriesName,
      keys: [key],
      complete: false,
    ),
    isNew: true,
    number: guess.number,
  );
}

/// La première série de [series] dont une clé (ou le nom replié, pour un
/// document sans clés) vaut [key] ; null sinon.
Series? findSeriesByKey(List<Series> series, String key) {
  for (final candidate in series) {
    if (candidate.keys.contains(key) || seriesKey(candidate.name) == key) {
      return candidate;
    }
  }
  return null;
}

/// Toutes les clés de [series] : les siennes, plus celle de son nom.
List<String> keysOf(Series series) {
  final nameKey = seriesKey(series.name);
  return [
    ...series.keys,
    if (nameKey.isNotEmpty && !series.keys.contains(nameKey)) nameKey,
  ];
}

/// Titre gardé pour un tome : le titre du catalogue, suivi de son sous-titre
/// (« Blacksad : Alors, tout tombe ») qui porte souvent le nom du tome.
String volumeTitleOf(BookMetadata metadata) {
  final title = metadata.title.trim();
  final subtitle = metadata.subtitle?.trim();
  if (subtitle == null || subtitle.isEmpty) return title;
  if (title.isEmpty) return subtitle;
  return '$title : $subtitle';
}
