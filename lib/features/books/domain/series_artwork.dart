import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/series_key.dart';
import 'package:flutter/foundation.dart';

/// Délai avant de redemander l'image d'une série qu'AniList ne connaissait
/// pas : une série récente peut y entrer entre-temps.
const artworkRetryInterval = Duration(days: 30);

/// Séries cherchées au plus à chaque ouverture de l'étagère (AniList accepte
/// 30 à 90 requêtes par minute selon l'état de son API ; au-delà, la passe
/// s'arrête).
const artworkLookupsPerOpening = 20;

/// Une œuvre qu'AniList propose pour un nom : ses titres (romaji, anglais,
/// natif, synonymes) et l'adresse de sa couverture.
class const ArtworkCandidate({
  required final List<String> titles,
  required final String? imageUrl,
}) {
  @override
  bool operator ==(Object other) =>
      other is ArtworkCandidate &&
      listEquals(other.titles, titles) &&
      other.imageUrl == imageUrl;

  @override
  int get hashCode => Object.hash(Object.hashAll(titles), imageUrl);
}

/// L'image de [series] à afficher : celle que la recherche a trouvée pour
/// son nom actuel ; null sinon (pas cherchée, rien trouvé, ou renommée
/// depuis).
String? artworkUrlOf(Series series) {
  final artwork = series.artwork;
  if (artwork == null || artwork.forName != series.name) return null;
  final url = artwork.url;
  return url == null || url.isEmpty ? null : url;
}

/// Vrai quand l'image de [series] est à chercher à [now] : jamais cherchée,
/// cherchée sous un autre nom, ou introuvable depuis
/// [artworkRetryInterval]. Une image trouvée n'est plus redemandée.
bool needsArtworkLookup(Series series, DateTime now) {
  if (seriesKey(series.name).isEmpty) return false;
  final artwork = series.artwork;
  if (artwork == null || artwork.forName != series.name) return true;
  if (artwork.url != null) return false;
  return now.difference(artwork.checkedAt) >= artworkRetryInterval;
}

/// Les séries de [series] dont l'image est à chercher à [now], [limit] au
/// plus, dans l'ordre reçu.
List<Series> seriesToIllustrate(
  Iterable<Series> series,
  DateTime now, {
  int limit = artworkLookupsPerOpening,
}) => [
  for (final one in series)
    if (needsArtworkLookup(one, now)) one,
].take(limit).toList();

/// L'image du premier candidat dont un titre désigne [series] (même clé
/// `seriesKey` qu'une des siennes, ou les mêmes lettres une fois les espaces
/// ôtées : « SPY×FAMILY » et « Spy x Family ») ; null quand aucun : mieux
/// vaut les initiales qu'une couverture d'une autre œuvre.
String? matchArtwork(Series series, List<ArtworkCandidate> candidates) {
  final keys = {seriesKey(series.name), ...series.keys}
    ..removeWhere((key) => key.isEmpty);
  final compact = keys.map(_compact).toSet();
  for (final candidate in candidates) {
    final url = candidate.imageUrl;
    if (url == null || url.isEmpty) continue;
    for (final title in candidate.titles) {
      final key = seriesKey(title);
      if (key.isEmpty) continue;
      if (keys.contains(key) || compact.contains(_compact(key))) return url;
    }
  }
  return null;
}

/// [key] sans espaces ni « x » isolé entre deux mots (le « × » des titres
/// japonais) : « Malcolm X » garde son « x ».
String _compact(String key) {
  final words = key.split(' ').where((word) => word.isNotEmpty).toList();
  return [
    for (var i = 0; i < words.length; i++)
      if (words[i] != 'x' || i == 0 || i == words.length - 1) words[i],
  ].join();
}
