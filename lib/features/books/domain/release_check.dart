import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/next_volume_status.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/series_key.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume_guess.dart';

/// Âge au-delà duquel ce qu'on sait du prochain tome est revérifié.
const releaseCheckInterval = Duration(days: 7);

/// Séries vérifiées au plus à chaque ouverture de l'étagère.
const releaseChecksPerOpening = 20;

/// Vrai quand la vérification de [entry] peut apprendre quelque chose à
/// [now] :
/// - jamais pour une série close, ni pour une date saisie par l'utilisateur
///   (la plus fiable) tant qu'elle porte sur un tome qu'il n'a pas ;
/// - jamais pour un tome déjà paru : rien de plus à en savoir avant qu'il
///   l'achète ;
/// - toujours quand personne n'a cherché, ou que l'information porte sur un
///   tome désormais possédé ;
/// - sinon quand la dernière vérification a [releaseCheckInterval] ou plus.
bool needsReleaseCheck(ShelfEntry entry, DateTime now) {
  if (entry.series.complete) return false;
  final info = entry.series.next;
  if (info == null || entry.owned.contains(info.number)) return true;
  if (info.source == ReleaseSource.user) return false;
  if (nextVolumeStatus(entry, now) == NextVolumeStatus.released) return false;
  return now.difference(info.checkedAt) >= releaseCheckInterval;
}

/// Les séries de [entries] à vérifier à [now] ([needsReleaseCheck]) :
/// celles que personne n'a cherchées ou dont l'information est périmée
/// d'abord, puis la vérification la plus ancienne ; [limit] au plus.
List<ShelfEntry> entriesToCheck(
  Iterable<ShelfEntry> entries,
  DateTime now, {
  int limit = releaseChecksPerOpening,
}) {
  final due = [
    for (final entry in entries)
      if (needsReleaseCheck(entry, now)) entry,
  ];
  DateTime? checked(ShelfEntry entry) {
    final info = entry.series.next;
    if (info == null || entry.owned.contains(info.number)) return null;
    return info.checkedAt;
  }

  due.sort((a, b) {
    final (left, right) = (checked(a), checked(b));
    if (left == null) return right == null ? 0 : -1;
    if (right == null) return 1;
    return left.compareTo(right);
  });
  return due.take(limit).toList();
}

/// Ce que les notices [records] de la BnF disent du tome [number] de
/// [entry], vérifié à [now] ; null quand rien n'est à écrire.
///
/// - Une notice de ce tome, dans cette série (`guessVolume` sur la notice ou
///   sur son titre seul : une clé de la série et ce numéro, en confiance
///   moyenne ou haute) : le tome existe.
///   - Avec une date au jour ou au mois (la plus proche quand plusieurs
///     notices en donnent) : [ReleaseStatus.announced] tant qu'elle n'est pas
///     passée, [ReleaseStatus.released] ensuite ; elle remplace même une date
///     saisie, car elle vient de l'éditeur.
///   - Sans : une date saisie pour ce tome est gardée (null) ; une notice
///     datée seulement d'une année à venir l'annonce sans date ; sinon
///     [ReleaseStatus.released].
/// - Aucune : [ReleaseStatus.unknown]. Ce qui était su de ce même tome (une
///   notice vue avant : la BnF ne retire pas ses notices) est gardé, vérifié
///   à [now] ; une date saisie reste telle quelle (null).
NextVolumeInfo? checkedRelease(
  ShelfEntry entry,
  int number,
  List<BookMetadata> records,
  DateTime now,
) {
  final keys = entry.series.keys.toSet();
  final dates = <ReleaseDate>[];
  final years = <int>[];
  var found = false;
  bool matches(VolumeGuess? guess) =>
      guess != null &&
      guess.confidence != GuessConfidence.low &&
      guess.number == number &&
      keys.contains(seriesKey(guess.seriesName));
  for (final record in records) {
    // La collection d'une notice n'est pas toujours la série : « One Piece -
    // Édition originale - Tome 113 » est rangé sous « Shonen One Piece ». Le
    // titre seul est donc lu aussi.
    if (!matches(guessVolume(record)) &&
        !matches(guessVolume(_titleOnly(record)))) {
      continue;
    }
    found = true;
    final published = record.publishedDate ?? '';
    if (ReleaseDate.tryParse(published) case final date?) {
      dates.add(date);
    } else if (_year.firstMatch(published) case final match?) {
      years.add(int.parse(match.group(0)!));
    }
  }

  final current = entry.series.next;
  final known = current != null && current.number == number ? current : null;
  if (!found) {
    if (known == null || known.status == ReleaseStatus.unknown) {
      return NextVolumeInfo(
        number: number,
        status: ReleaseStatus.unknown,
        source: ReleaseSource.bnf,
        checkedAt: now,
      );
    }
    if (known.source == ReleaseSource.user) return null;
    return NextVolumeInfo(
      number: known.number,
      status: known.status,
      date: known.date,
      source: known.source,
      checkedAt: now,
    );
  }

  dates.sort(_byStart);
  final date = dates.firstOrNull;
  if (date == null) {
    if (known?.source == ReleaseSource.user) return null;
    final later = years.isNotEmpty && years.every((year) => year > now.year);
    return NextVolumeInfo(
      number: number,
      status: later ? ReleaseStatus.announced : ReleaseStatus.released,
      source: ReleaseSource.bnf,
      checkedAt: now,
    );
  }
  return NextVolumeInfo(
    number: number,
    status: date.isOnOrAfter(now)
        ? ReleaseStatus.announced
        : ReleaseStatus.released,
    date: date,
    source: ReleaseSource.bnf,
    checkedAt: now,
  );
}

/// La date que l'utilisateur a saisie pour le prochain tome de [entry], tant
/// qu'elle porte sur ce tome ; null sinon (aucune, une autre source, ou un
/// tome désormais possédé).
ReleaseDate? enteredDateOf(ShelfEntry entry) {
  final info = entry.series.next;
  if (info == null || info.source != ReleaseSource.user) return null;
  return info.number == upcomingVolumeNumber(entry) ? info.date : null;
}

/// La date de sortie [date] du tome [number], saisie par l'utilisateur à
/// [now] : annoncée tant qu'elle n'est pas passée, parue sinon.
NextVolumeInfo enteredRelease(int number, ReleaseDate date, DateTime now) =>
    NextVolumeInfo(
      number: number,
      status: date.isOnOrAfter(now)
          ? ReleaseStatus.announced
          : ReleaseStatus.released,
      date: date,
      source: ReleaseSource.user,
      checkedAt: now,
    );

/// [record] sans sa série structurée : ce que son titre dit seul.
BookMetadata _titleOnly(BookMetadata record) => BookMetadata(
  title: record.title,
  subtitle: record.subtitle,
  authors: record.authors,
);

/// Un millésime de quatre chiffres.
final _year = RegExp(r'\d{4}');

/// Ordre chronologique ; un mois seul passe avant les jours de ce mois.
int _byStart(ReleaseDate a, ReleaseDate b) {
  if (a.year != b.year) return a.year.compareTo(b.year);
  if (a.month != b.month) return a.month.compareTo(b.month);
  return (a.day ?? 0).compareTo(b.day ?? 0);
}
