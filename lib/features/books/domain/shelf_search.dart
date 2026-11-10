import 'package:an_ki/core/text/text_folding.dart';
import 'package:an_ki/features/books/domain/shelf.dart';

/// Les séries de [entries] dont le nom contient [query] (sans majuscules,
/// accents ni tirets), de A à Z ; toutes les séries pour une recherche vide.
/// Le tri suit le nom replié, puis le nom tel quel, puis l'id pour départager.
List<ShelfEntry> searchShelf(List<ShelfEntry> entries, String query) {
  final folded = foldForMatching(query);
  final keyed = [
    for (final entry in entries)
      (key: foldForMatching(entry.series.name), entry: entry),
  ];
  return [
    for (final item in keyed..sort(_byName))
      if (folded.isEmpty || item.key.contains(folded)) item.entry,
  ];
}

int _byName(
  ({String key, ShelfEntry entry}) a,
  ({String key, ShelfEntry entry}) b,
) {
  final byKey = a.key.compareTo(b.key);
  if (byKey != 0) return byKey;
  final byName = a.entry.series.name.compareTo(b.entry.series.name);
  // Deux séries de même nom (doublon à fusionner) : un ordre stable.
  return byName != 0 ? byName : a.entry.series.id.compareTo(b.entry.series.id);
}
