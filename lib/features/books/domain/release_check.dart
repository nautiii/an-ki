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

/// Vrai quand Google Books peut préciser ce que les notices [bnfRecords] de
/// la BnF disent du tome [number] de [entry] à [now] : la BnF n'en a aucune
/// notice, ou seulement une annonce d'une année à venir, sans date. Jamais
/// quand ce tome a déjà une date saisie (Google ne la remplace pas), une
/// date ou un « paru » de la BnF (elle l'emporte, même muette ce jour-là),
/// ou une date Google passée (le tome devrait être sorti).
bool needsGoogleCheck(
  ShelfEntry entry,
  int number,
  List<BookMetadata> bnfRecords,
  DateTime now,
) {
  final known = _known(entry, number);
  if (known != null &&
      (known.source == ReleaseSource.user ||
          _bnfSettled(known) ||
          (known.source == ReleaseSource.googleBooks && _passed(known, now)))) {
    return false;
  }
  final bnf = _matchOf(entry, number, bnfRecords);
  return bnf == null || (bnf.dates.isEmpty && bnf.isLater(now));
}

/// Ce que les notices [records] de la BnF, et les volumes [google] de Google
/// Books quand il a été interrogé ([needsGoogleCheck]), disent du tome
/// [number] de [entry], vérifié à [now] ; null quand rien n'est à écrire.
///
/// Une notice ou un volume compte quand `guessVolume` (sur la notice, ou sur
/// son titre seul) y lit une clé de la série et ce numéro, en confiance
/// moyenne ou haute. Par ordre de préférence :
/// 1. Une notice BnF datée au jour ou au mois (la plus proche quand
///    plusieurs en donnent) : [ReleaseStatus.announced] tant qu'elle n'est
///    pas passée, [ReleaseStatus.released] ensuite ; elle remplace même une
///    date saisie, car elle vient de l'éditeur.
/// 2. Un volume Google daté au jour ou au mois, pas encore passé (le plus
///    proche ; de l'année que la BnF annonce, quand elle en annonce une) :
///    [ReleaseStatus.announced], source Google Books. Ses dates passées ne
///    disent pas « paru » : la mesure de l'étape 9 en a trouvé de fausses.
///    Ni une date saisie de ce tome, ni une date ou un « paru » de la BnF
///    déjà sus ne sont remplacés.
/// 3. Une notice BnF sans date : une date saisie pour ce tome est gardée
///    (null) ; une notice datée seulement d'une année à venir l'annonce sans
///    date (une date Google déjà sue reste tant que Google n'a pu être
///    interrogé) ; sinon [ReleaseStatus.released].
/// 4. Aucune : [ReleaseStatus.unknown]. Ce qui était su de ce même tome (une
///    notice vue avant : la BnF ne retire pas ses notices) est gardé,
///    vérifié à [now] ; une date saisie reste telle quelle (null), une date
///    Google aussi tant que Google n'a pu être interrogé ou qu'elle est
///    passée (sinon elle n'y est plus : [ReleaseStatus.unknown]).
NextVolumeInfo? checkedRelease(
  ShelfEntry entry,
  int number,
  List<BookMetadata> records,
  DateTime now, {
  List<BookMetadata>? google,
}) {
  final known = _known(entry, number);
  final bnf = _matchOf(entry, number, records);
  final unknown = NextVolumeInfo(
    number: number,
    status: ReleaseStatus.unknown,
    source: ReleaseSource.bnf,
    checkedAt: now,
  );

  if (bnf?.dates.firstOrNull case final date?) {
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

  if (google != null &&
      known?.source != ReleaseSource.user &&
      !_bnfSettled(known)) {
    final years = bnf?.years.toSet();
    final announced = [
      for (final date
          in _matchOf(entry, number, google)?.dates ?? const <ReleaseDate>[])
        if (date.isOnOrAfter(now) &&
            (years == null || years.contains(date.year)))
          date,
    ];
    if (announced.firstOrNull case final date?) {
      return NextVolumeInfo(
        number: number,
        status: ReleaseStatus.announced,
        date: date,
        source: ReleaseSource.googleBooks,
        checkedAt: now,
      );
    }
  }
  // Une date Google déjà sue n'est pas revue si Google n'a pu répondre.
  final keepGoogle =
      known?.source == ReleaseSource.googleBooks && google == null;

  if (bnf == null) {
    if (known == null || known.status == ReleaseStatus.unknown) return unknown;
    return switch (known.source) {
      ReleaseSource.user => null,
      ReleaseSource.googleBooks =>
        keepGoogle || _passed(known, now) ? null : unknown,
      ReleaseSource.bnf => NextVolumeInfo(
        number: known.number,
        status: known.status,
        date: known.date,
        source: known.source,
        checkedAt: now,
      ),
    };
  }

  if (known?.source == ReleaseSource.user) return null;
  final later = bnf.isLater(now);
  if (later && keepGoogle) return null;
  return NextVolumeInfo(
    number: number,
    status: later ? ReleaseStatus.announced : ReleaseStatus.released,
    source: ReleaseSource.bnf,
    checkedAt: now,
  );
}

/// Vrai quand la BnF a déjà daté [known], ou l'a dit paru : Google ne la
/// contredit pas.
bool _bnfSettled(NextVolumeInfo? known) =>
    known != null &&
    known.source == ReleaseSource.bnf &&
    (known.date != null || known.status == ReleaseStatus.released);

/// Vrai quand la date de [info] est passée à [now].
bool _passed(NextVolumeInfo info, DateTime now) =>
    !(info.date?.isOnOrAfter(now) ?? true);

/// Ce que [entry] savait déjà du tome [number] ; null pour un autre tome.
NextVolumeInfo? _known(ShelfEntry entry, int number) {
  final current = entry.series.next;
  return current != null && current.number == number ? current : null;
}

/// Les dates lues dans les notices d'un même tome.
class const _Match({
  /// Dates au jour ou au mois, la plus proche d'abord.
  required final List<ReleaseDate> dates,

  /// Millésimes des notices datées d'une année seulement.
  required final List<int> years,
}) {
  /// Vrai quand seules des années à venir datent le tome.
  bool isLater(DateTime now) =>
      years.isNotEmpty && years.every((year) => year > now.year);
}

/// Les notices de [records] qui décrivent le tome [number] de [entry] ; null
/// quand aucune.
_Match? _matchOf(ShelfEntry entry, int number, List<BookMetadata> records) {
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
    // La collection d'une notice n'est pas toujours la série, et une étagère
    // peut garder une série devinée avant la correction de `guessVolume`
    // (« Shonen One Piece » pour « One Piece - Tome 113 »). Le titre seul est
    // donc lu aussi.
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
  if (!found) return null;
  return _Match(dates: dates..sort(_byStart), years: years);
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
