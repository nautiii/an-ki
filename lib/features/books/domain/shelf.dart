import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_number.dart';
import 'package:flutter/foundation.dart';

/// L'étagère : une entrée par série, plus les tomes « à classer ».
class const Shelf({
  /// Une entrée par série, dans l'ordre reçu ; à l'écran de trier.
  required final List<ShelfEntry> entries,

  /// Tomes sans série, sans numéro (ou hors de 1 à `maxVolumeNumber`), ou d'une
  /// série inconnue : le plus récent d'abord.
  required final List<Volume> unclassified,
}) {
  @override
  bool operator ==(Object other) =>
      other is Shelf &&
      listEquals(other.entries, entries) &&
      listEquals(other.unclassified, unclassified);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(entries), Object.hashAll(unclassified));
}

/// Ce que l'on possède d'une série, et ce qu'il reste à acheter.
class const ShelfEntry({
  required final Series series,

  /// Tomes numérotés de la série, par numéro puis du plus ancien au plus
  /// récent (deux éditions d'un même numéro restent toutes les deux).
  required final List<Volume> volumes,

  /// Numéros possédés, triés, sans doublon.
  required final List<int> owned,

  /// Dernier numéro possédé ; null quand on n'en possède aucun.
  final int? last,

  /// Numéros manquants entre 1 et [last].
  required final List<int> holes,

  /// Prochain tome à acheter : le premier trou, sinon [last] + 1 (1 pour une
  /// série vide). Null quand la série est terminée et sans trou.
  final int? nextToBuy,

  /// Couverture du dernier tome possédé qui en a une.
  final String? coverUrl,
}) {
  @override
  bool operator ==(Object other) =>
      other is ShelfEntry &&
      other.series == series &&
      listEquals(other.volumes, volumes) &&
      listEquals(other.owned, owned) &&
      other.last == last &&
      listEquals(other.holes, holes) &&
      other.nextToBuy == nextToBuy &&
      other.coverUrl == coverUrl;

  @override
  int get hashCode => Object.hash(
    series,
    Object.hashAll(volumes),
    Object.hashAll(owned),
    last,
    Object.hashAll(holes),
    nextToBuy,
    coverUrl,
  );
}

/// Range [volumes] dans leurs [series] : par série, les numéros possédés, le
/// dernier, les trous, le prochain à acheter et la couverture ; le reste est
/// « à classer ».
Shelf shelfOf(List<Series> series, List<Volume> volumes) {
  final byId = {for (final s in series) s.id: s};
  final grouped = <String, List<Volume>>{};
  final unclassified = <Volume>[];
  for (final volume in volumes) {
    final seriesId = volume.seriesId;
    final number = volume.number;
    // Un numéro hors de 1 à [maxVolumeNumber] (document corrompu, saisie
    // ancienne) ne doit pas créer des milliers de trous : à classer.
    if (seriesId != null &&
        number != null &&
        number >= 1 &&
        number <= maxVolumeNumber &&
        byId.containsKey(seriesId)) {
      grouped.putIfAbsent(seriesId, () => []).add(volume);
    } else {
      unclassified.add(volume);
    }
  }
  unclassified.sort((a, b) => b.addedAt.compareTo(a.addedAt));

  return Shelf(
    entries: [
      for (final s in series) _entryOf(s, grouped[s.id] ?? const <Volume>[]),
    ],
    unclassified: unclassified,
  );
}

ShelfEntry _entryOf(Series series, List<Volume> numbered) {
  final sorted = [...numbered]
    ..sort((a, b) {
      final byNumber = a.number!.compareTo(b.number!);
      return byNumber != 0 ? byNumber : a.addedAt.compareTo(b.addedAt);
    });
  final ownedSet = sorted.map((v) => v.number!).toSet();
  final owned = ownedSet.toList();
  final last = owned.isEmpty ? null : owned.last;
  final holes = [
    if (last != null)
      for (var n = 1; n < last; n++)
        if (!ownedSet.contains(n)) n,
  ];
  final int? nextToBuy;
  if (holes.isNotEmpty) {
    nextToBuy = holes.first;
  } else if (series.complete) {
    nextToBuy = null;
  } else {
    nextToBuy = (last ?? 0) + 1;
  }

  // La couverture du plus haut numéro qui en a une : un dernier tome sans
  // image ne vide pas la vignette de la série.
  String? coverUrl;
  for (final volume in sorted.reversed) {
    if (volume.imageUrl case final url? when url.isNotEmpty) {
      coverUrl = url;
      break;
    }
  }

  return ShelfEntry(
    series: series,
    volumes: sorted,
    owned: owned,
    last: last,
    holes: holes,
    nextToBuy: nextToBuy,
    coverUrl: coverUrl,
  );
}
