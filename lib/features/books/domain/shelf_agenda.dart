import 'package:an_ki/features/books/domain/next_volume_status.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_search.dart';

/// Un tome paru que l'on n'a pas : une ligne de « À acheter ».
class const ShelfPurchase({
  required final ShelfEntry entry,

  /// Numéro du tome paru (`upcomingVolumeNumber`).
  required final int number,
}) {
  @override
  bool operator ==(Object other) =>
      other is ShelfPurchase && other.entry == entry && other.number == number;

  @override
  int get hashCode => Object.hash(entry, number);
}

/// Un tome annoncé, daté : une ligne de « Prochaines sorties ».
class const UpcomingRelease({
  required final ShelfEntry entry,
  required final int number,
  required final ReleaseDate date,
}) {
  @override
  bool operator ==(Object other) =>
      other is UpcomingRelease &&
      other.entry == entry &&
      other.number == number &&
      other.date == date;

  @override
  int get hashCode => Object.hash(entry, number, date);
}

/// « À acheter » : par série de [entries], le tome paru qu'elle n'a pas
/// ([NextVolumeStatus.released] à [today]), de A à Z.
List<ShelfPurchase> toBuyOf(List<ShelfEntry> entries, DateTime today) => [
  for (final entry in searchShelf(entries, ''))
    if (nextVolumeStatus(entry, today) == NextVolumeStatus.released)
      ShelfPurchase(entry: entry, number: upcomingVolumeNumber(entry)!),
];

/// « Prochaines sorties » : les tomes annoncés de [entries] dont la date
/// n'est pas passée à [today], la plus proche d'abord, [limit] au plus. Un
/// mois seul passe après les jours de ce mois (il peut en être le dernier) ;
/// à date égale, de A à Z.
List<UpcomingRelease> upcomingReleasesOf(
  List<ShelfEntry> entries,
  DateTime today, {
  int limit = 3,
}) {
  final releases = [
    for (final entry in searchShelf(entries, ''))
      if (nextVolumeStatus(entry, today) == NextVolumeStatus.announced)
        if (entry.series.next?.date case final date?)
          UpcomingRelease(
            entry: entry,
            number: upcomingVolumeNumber(entry)!,
            date: date,
          ),
  ];
  // Tri stable : `searchShelf` a déjà rangé de A à Z.
  final indexed = releases.indexed.toList()
    ..sort((a, b) {
      final byDate = _dayOf(a.$2.date).compareTo(_dayOf(b.$2.date));
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
  return [for (final (_, release) in indexed.take(limit)) release];
}

/// Clé de tri d'une date : un mois seul compte comme son 32e jour.
int _dayOf(ReleaseDate date) =>
    (date.year * 12 + date.month) * 32 + (date.day ?? 32);
