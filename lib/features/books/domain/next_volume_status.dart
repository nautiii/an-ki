import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';

/// Ce que l'étagère dit du prochain tome d'une série.
enum NextVolumeStatus {
  /// La série est terminée et close : rien à attendre.
  complete,

  /// Un tome est paru et l'utilisateur ne l'a pas : « Tome 109 paru, vous ne
  /// l'avez pas ».
  released,

  /// Une date de sortie, au jour ou au mois, n'est pas passée.
  announced,

  /// Aucune source ne sait : « date inconnue », jamais « non annoncé ».
  unknown,
}

/// Statut du prochain tome de [entry] à [today] (seuls l'année, le mois et le
/// jour comptent ; rien ici ne lit l'horloge).
///
/// 1. Série close : [NextVolumeStatus.complete].
/// 2. Pas d'information, ou elle porte sur un tome déjà possédé (périmée) :
///    [NextVolumeStatus.unknown].
/// 3. La source dit « paru » : [NextVolumeStatus.released].
/// 4. Une date : [NextVolumeStatus.announced] si elle n'est pas passée (un mois
///    seul compte jusqu'à sa fin), sinon [NextVolumeStatus.released] (le tome
///    devrait être sorti).
/// 5. Sinon [NextVolumeStatus.unknown] : une annonce sans date n'apprend rien.
NextVolumeStatus nextVolumeStatus(ShelfEntry entry, DateTime today) {
  if (entry.series.complete) return NextVolumeStatus.complete;
  final info = entry.series.next;
  if (info == null || entry.owned.contains(info.number)) {
    return NextVolumeStatus.unknown;
  }
  if (info.status == ReleaseStatus.released) return NextVolumeStatus.released;
  final date = info.date;
  if (date == null) return NextVolumeStatus.unknown;
  return date.isOnOrAfter(today)
      ? NextVolumeStatus.announced
      : NextVolumeStatus.released;
}

/// Numéro du prochain tome de [entry], celui dont [nextVolumeStatus] parle :
/// le tome qu'une source a renseigné s'il n'est pas déjà possédé, sinon le
/// suivant du dernier possédé (1 pour une série vide) ; null pour une série
/// close.
int? upcomingVolumeNumber(ShelfEntry entry) {
  if (entry.series.complete) return null;
  final info = entry.series.next;
  if (info != null && !entry.owned.contains(info.number)) return info.number;
  return (entry.last ?? 0) + 1;
}
