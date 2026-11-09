import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_placement.dart';
import 'package:flutter/foundation.dart';

/// L'étagère d'un invité, marquée pour le compte Google qui va la reprendre
/// (`transferTo`) : lue sur le serveur par l'invité avant la connexion, gardée
/// en mémoire, car ce compte ne pourra pas la lire.
class const MarkedShelf({
  required final String guestUid,
  required final List<Series> series,
  required final List<Volume> volumes,

  /// Anciens documents `books` de l'invité, repris par leur `uid`.
  required final List<String> legacyBookIds,
}) {
  bool get isEmpty =>
      series.isEmpty && volumes.isEmpty && legacyBookIds.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is MarkedShelf &&
      other.guestUid == guestUid &&
      listEquals(other.series, series) &&
      listEquals(other.volumes, volumes) &&
      listEquals(other.legacyBookIds, legacyBookIds);

  @override
  int get hashCode => Object.hash(
    guestUid,
    Object.hashAll(series),
    Object.hashAll(volumes),
    Object.hashAll(legacyBookIds),
  );
}

/// Ce que le compte cible écrit pour reprendre une [MarkedShelf].
class const ShelfTakeOverPlan({
  required final String guestUid,

  /// Séries de l'invité sans équivalent chez la cible : copiées avec leur id.
  required final List<Series> seriesToCopy,

  /// Clés de l'invité ajoutées aux séries de la cible qu'elles rejoignent, par
  /// id de série cible : un scan sous l'ancien nom y retrouve la série.
  required final Map<String, List<String>> keysToAdd,

  /// Tomes de l'invité que la cible n'a pas, rattachés à la série retenue.
  required final List<Volume> volumesToCopy,

  /// Documents marqués de l'invité, supprimés une fois la copie faite.
  required final List<String> guestSeriesIds,
  required final List<String> guestVolumeIds,

  /// Anciens documents `books` de l'invité, repris par leur `uid`.
  required final List<String> legacyBookIds,
}) {
  @override
  bool operator ==(Object other) =>
      other is ShelfTakeOverPlan &&
      other.guestUid == guestUid &&
      listEquals(other.seriesToCopy, seriesToCopy) &&
      _sameKeys(other.keysToAdd, keysToAdd) &&
      listEquals(other.volumesToCopy, volumesToCopy) &&
      listEquals(other.guestSeriesIds, guestSeriesIds) &&
      listEquals(other.guestVolumeIds, guestVolumeIds) &&
      listEquals(other.legacyBookIds, legacyBookIds);

  @override
  int get hashCode => Object.hash(
    guestUid,
    Object.hashAll(seriesToCopy),
    Object.hashAllUnordered(keysToAdd.keys),
    Object.hashAll(volumesToCopy),
    Object.hashAll(guestSeriesIds),
    Object.hashAll(guestVolumeIds),
    Object.hashAll(legacyBookIds),
  );
}

/// Égalité de deux cartes de clés, listes comparées par contenu.
bool _sameKeys(Map<String, List<String>> a, Map<String, List<String>> b) =>
    a.length == b.length &&
    a.entries.every((entry) => listEquals(b[entry.key], entry.value));

/// Reprise de l'étagère [marked] par un compte qui a déjà [targetSeries] et
/// [targetVolumes].
///
/// - Une série de l'invité qui partage une clé avec une série de la cible la
///   rejoint (ses clés s'y ajoutent) ; sinon elle est copiée avec son id.
/// - Un tome dont la cible a déjà l'id ou l'ISBN est ignoré : la cible garde
///   le sien et son classement. Les autres sont copiés, rattachés à la série
///   retenue.
/// - Tous les documents marqués de l'invité sont ensuite supprimés.
ShelfTakeOverPlan planShelfTakeOver(
  MarkedShelf marked, {
  required List<Series> targetSeries,
  required List<Volume> targetVolumes,
}) {
  final seriesMap = <String, String>{};
  final seriesToCopy = <Series>[];
  final keysToAdd = <String, List<String>>{};
  for (final series in marked.series) {
    final keys = keysOf(series);
    Series? match;
    for (final key in keys) {
      match = findSeriesByKey(targetSeries, key);
      if (match != null) break;
    }
    if (match == null) {
      seriesToCopy.add(series);
      continue;
    }
    seriesMap[series.id] = match.id;
    final known = {...keysOf(match), ...?keysToAdd[match.id]};
    final added = [
      for (final key in keys)
        if (!known.contains(key)) key,
    ];
    if (added.isNotEmpty) {
      keysToAdd[match.id] = [...?keysToAdd[match.id], ...added];
    }
  }

  final ownedIds = {for (final volume in targetVolumes) volume.id};
  final ownedIsbns = {for (final volume in targetVolumes) ?volume.isbn};
  final volumesToCopy = [
    for (final volume in marked.volumes)
      if (!ownedIds.contains(volume.id) &&
          (volume.isbn == null || !ownedIsbns.contains(volume.isbn)))
        _moved(volume, seriesMap),
  ];

  return ShelfTakeOverPlan(
    guestUid: marked.guestUid,
    seriesToCopy: seriesToCopy,
    keysToAdd: keysToAdd,
    volumesToCopy: volumesToCopy,
    guestSeriesIds: [for (final series in marked.series) series.id],
    guestVolumeIds: [for (final volume in marked.volumes) volume.id],
    legacyBookIds: marked.legacyBookIds,
  );
}

/// [volume] rattaché à la série que sa série d'origine rejoint, s'il y en a.
Volume _moved(Volume volume, Map<String, String> seriesMap) {
  final target = seriesMap[volume.seriesId];
  if (target == null) return volume;
  return Volume(
    id: volume.id,
    seriesId: target,
    number: volume.number,
    isbn: volume.isbn,
    title: volume.title,
    authors: volume.authors,
    imageUrl: volume.imageUrl,
    publisher: volume.publisher,
    publishedDate: volume.publishedDate,
    lookup: volume.lookup,
    addedAt: volume.addedAt,
  );
}
