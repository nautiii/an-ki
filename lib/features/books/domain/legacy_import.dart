import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/isbn.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_guess.dart';
import 'package:an_ki/features/books/domain/volume_placement.dart';
import 'package:flutter/foundation.dart';

/// Un livre de l'ancienne liste (`books`, un document par scan, propriétaire
/// dans son champ `uid`), pas encore importé dans l'étagère.
class const LegacyBook({
  required final String id,
  required final String title,
  required final List<String> authors,

  /// Tel que la caméra l'a lu, jamais vérifié.
  required final String isbn,
  final String? imageUrl,
  final String? publishedDate,

  /// Absent sur un document très ancien.
  final DateTime? scannedAt,
}) {
  @override
  bool operator ==(Object other) =>
      other is LegacyBook &&
      other.id == id &&
      other.title == title &&
      listEquals(other.authors, authors) &&
      other.isbn == isbn &&
      other.imageUrl == imageUrl &&
      other.publishedDate == publishedDate &&
      other.scannedAt == scannedAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    Object.hashAll(authors),
    isbn,
    imageUrl,
    publishedDate,
    scannedAt,
  );
}

/// Ce que l'import écrit pour un tome : une écriture atomique (un même lot).
class const LegacyImportEntry({
  /// Le tome à écrire ; null quand l'étagère l'a déjà (rescanné entre-temps) :
  /// seuls les anciens documents sont marqués.
  final Volume? volume,

  /// La série à créer avec ce tome, la première fois qu'elle sert.
  final Series? newSeries,

  /// Les anciens documents de ce tome (un ISBN scanné plusieurs fois), tous
  /// marqués importés.
  required final List<String> legacyBookIds,
}) {
  @override
  bool operator ==(Object other) =>
      other is LegacyImportEntry &&
      other.volume == volume &&
      other.newSeries == newSeries &&
      listEquals(other.legacyBookIds, legacyBookIds);

  @override
  int get hashCode =>
      Object.hash(volume, newSeries, Object.hashAll(legacyBookIds));
}

/// Plan d'import des anciens livres dans l'étagère.
class const LegacyImportPlan({required final List<LegacyImportEntry> entries}) {
  bool get isEmpty => entries.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is LegacyImportPlan && listEquals(other.entries, entries);

  @override
  int get hashCode => Object.hashAll(entries);
}

/// Range les anciens [books] dans l'étagère de [series] et [ownedVolumeIds].
///
/// - Un tome par ISBN (id = ISBN-13 normalisé ; l'id de l'ancien document
///   quand l'ISBN est illisible) : les doublons fusionnent, le plus ancien scan
///   donne la date d'ajout et les champs, les suivants comblent ses manques.
/// - Un tome que l'étagère a déjà n'est pas réécrit : un rescan plus récent
///   garde son classement.
/// - `guessVolume` sur le titre : confiance moyenne ou haute, le tome rejoint
///   la série de même clé, ou une nouvelle série (créée une fois, d'id
///   [newSeriesId]) ; sinon il reste « à classer ».
/// - Un livre sans date de scan prend [now].
///
/// Chaque ancien document figure dans une entrée, pour être marqué importé :
/// l'import ne repasse jamais, et un tome retiré ensuite ne revient pas.
LegacyImportPlan planLegacyImport({
  required List<LegacyBook> books,
  required List<Series> series,
  required Set<String> ownedVolumeIds,
  required DateTime now,
  required String Function() newSeriesId,
}) {
  final sorted = [...books]
    ..sort((a, b) => (a.scannedAt ?? now).compareTo(b.scannedAt ?? now));
  final byVolume = <String, List<LegacyBook>>{};
  for (final book in sorted) {
    final id = normalizeIsbn(book.isbn) ?? book.id;
    byVolume.putIfAbsent(id, () => []).add(book);
  }

  final known = [...series];
  final entries = <LegacyImportEntry>[];
  for (final MapEntry(key: id, value: group) in byVolume.entries) {
    final legacyIds = [for (final book in group) book.id];
    if (ownedVolumeIds.contains(id)) {
      entries.add(LegacyImportEntry(legacyBookIds: legacyIds));
      continue;
    }
    final first = group.first;
    final title = _firstNonEmpty(group.map((b) => b.title)) ?? '';
    final authors = group
        .map((b) => b.authors)
        .firstWhere((a) => a.isNotEmpty, orElse: () => const []);
    final placement = placeVolume(
      guessVolume(BookMetadata(title: title, authors: authors)),
      known,
      newSeriesId: newSeriesId,
    );
    if (placement != null && placement.isNew) known.add(placement.series);
    entries.add(
      LegacyImportEntry(
        volume: Volume(
          id: id,
          seriesId: placement?.series.id,
          number: placement?.number,
          isbn: normalizeIsbn(first.isbn),
          title: title,
          authors: authors,
          imageUrl: _firstNonEmpty(group.map((b) => b.imageUrl)),
          publishedDate: _firstNonEmpty(group.map((b) => b.publishedDate)),
          // L'ancienne liste venait de Google Books : le livre était trouvé.
          lookup: LookupState.found,
          addedAt: first.scannedAt ?? now,
        ),
        newSeries: placement != null && placement.isNew
            ? placement.series
            : null,
        legacyBookIds: legacyIds,
      ),
    );
  }
  return LegacyImportPlan(entries: entries);
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) return value;
  }
  return null;
}
