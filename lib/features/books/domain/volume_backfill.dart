import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/series_key.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_guess.dart';
import 'package:an_ki/features/books/domain/volume_placement.dart';

// « J'ai aussi les tomes précédents » : les tomes qu'on n'a pas scannés sont
// ajoutés sans ISBN, en attente, puis complétés par une recherche de leur
// série et de leur numéro (BnF, puis Google Books).

/// Tomes complétés au plus par passe : la BnF a déjà refusé des rafales de
/// requêtes (D15) ; une longue série se complète en plusieurs ouvertures.
const backfillsPerPass = 40;

/// Les numéros de 1 à [number] − 1 que [entry] ne possède pas, croissants.
List<int> missingBefore(ShelfEntry entry, int number) {
  final owned = entry.owned.toSet();
  return [
    for (var n = 1; n < number; n++)
      if (!owned.contains(n)) n,
  ];
}

/// Vrai pour un tome ajouté sans ISBN dont les infos restent à chercher par
/// sa série et son numéro.
bool awaitsBackfill(Volume volume) =>
    volume.lookup == LookupState.pending &&
    volume.isbn == null &&
    volume.seriesId != null &&
    volume.number != null;

/// L'éditeur le plus courant des tomes de [entry] (à égalité, celui du plus
/// haut numéro) ; null quand aucun n'en a. Une recherche le préfère : les
/// tomes d'une même collection viennent d'ordinaire du même éditeur.
String? usualPublisherOf(ShelfEntry entry) {
  final counts = <String, int>{};
  final names = <String, String>{};
  // Du plus haut numéro au plus bas : à égalité, le premier vu l'emporte.
  for (final volume in entry.volumes.reversed) {
    final publisher = volume.publisher?.trim();
    if (publisher == null || publisher.isEmpty) continue;
    final key = seriesKey(publisher);
    names.putIfAbsent(key, () => publisher);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  String? best;
  for (final MapEntry(:key, :value) in counts.entries) {
    if (best == null || value > counts[best]!) best = key;
  }
  return best == null ? null : names[best];
}

/// La notice de [records] qui décrit le tome [number] de la série aux clés
/// [keys] (`describesVolume`) ; null quand aucune. La BnF rattache à une
/// série bien des livres de ce numéro (rééditions, roman d'un autre éditeur,
/// art-book « One piece : color walk 1 », coffret) ; on préfère, dans
/// l'ordre :
/// 1. l'éditeur [publisher] (celui des tomes déjà là), sinon le plus
///    fréquent parmi ces notices (Glénat ×4 contre Hachette ×2 pour le
///    tome 1 de One Piece) ;
/// 2. un tome que la collection de l'éditeur numérote dans la série
///    (`numberedInCollection`) ;
/// 3. la parution la plus récente (l'impression qu'on trouve en librairie) ;
/// 4. l'ordre des notices.
BookMetadata? backfillRecordOf(
  Set<String> keys,
  int number,
  List<BookMetadata> records, {
  String? publisher,
}) {
  final matching = [
    for (final record in records)
      if (describesVolume(record, keys, number)) record,
  ];
  final known = publisher == null ? '' : seriesKey(publisher);
  final wanted = known.isNotEmpty ? known : _mostFrequentPublisher(matching);
  int score(BookMetadata record) =>
      (_samePublisher(seriesKey(record.publisher ?? ''), wanted) ? 2 : 0) +
      (record.numberedInCollection ? 1 : 0);
  BookMetadata? best;
  for (final record in matching) {
    if (best == null) {
      best = record;
      continue;
    }
    final byScore = score(record).compareTo(score(best));
    if (byScore > 0 ||
        (byScore == 0 && _year(record).compareTo(_year(best)) > 0)) {
      best = record;
    }
  }
  return best;
}

/// La clé (`seriesKey`) de l'éditeur le plus fréquent de [records], le
/// premier vu à égalité ; vide quand aucun n'en a.
String _mostFrequentPublisher(List<BookMetadata> records) {
  final counts = <String, int>{};
  for (final record in records) {
    final key = seriesKey(record.publisher ?? '');
    if (key.isNotEmpty) counts[key] = (counts[key] ?? 0) + 1;
  }
  var best = '';
  for (final MapEntry(:key, :value) in counts.entries) {
    if (best.isEmpty || value > counts[best]!) best = key;
  }
  return best;
}

/// Année de parution d'une notice (« cop. 2006 » → `2006`), 0 sans année.
int _year(BookMetadata record) =>
    int.tryParse(
      _fourDigits.firstMatch(record.publishedDate ?? '')?.group(0) ?? '',
    ) ??
    0;

final _fourDigits = RegExp(r'\d{4}');

/// Même éditeur, à quelques mots près (« Glénat », « Glénat Manga »,
/// « Éditions Glénat »), sur des clés de `seriesKey`.
bool _samePublisher(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  return ' $a '.contains(' $b ') || ' $b '.contains(' $a ');
}

/// [volume] complété par [record] : titre, auteurs, couverture, éditeur, date
/// et ISBN de la notice ; sans notice, il est complet tel quel (« Tome 5 »).
/// Sa série, son numéro, son id et sa date d'ajout restent.
Volume backfilled(Volume volume, BookMetadata? record) => Volume(
  id: volume.id,
  seriesId: volume.seriesId,
  number: volume.number,
  isbn: record?.isbn ?? volume.isbn,
  title: record == null ? volume.title : volumeTitleOf(record),
  authors: record?.authors ?? volume.authors,
  imageUrl: record?.imageUrl ?? volume.imageUrl,
  publisher: record?.publisher ?? volume.publisher,
  publishedDate: record?.publishedDate ?? volume.publishedDate,
  lookup: LookupState.found,
  addedAt: volume.addedAt,
);

/// Les tomes de [volumes] qu'un tome scanné, rangé au numéro [number] de
/// [seriesId], remplace : ceux de ce numéro qui n'ont pas été scannés
/// (ajoutés à la main ou par « les tomes précédents », leur id n'est pas un
/// ISBN). Deux tomes scannés d'un même numéro restent tous les deux (deux
/// éditions).
List<String> replacedByScan(
  List<Volume> volumes, {
  required String seriesId,
  required int number,
  required String scannedId,
}) => [
  for (final volume in volumes)
    if (volume.id != scannedId &&
        volume.seriesId == seriesId &&
        volume.number == number &&
        volume.id != volume.isbn)
      volume.id,
];

/// Les tomes de [volumes] que [volume], rangé au numéro [number] de
/// [seriesId], remplace : ceux de [replacedByScan] s'il a été scanné (son id
/// est son ISBN), aucun sinon.
List<String> replacedBy(
  List<Volume> volumes,
  Volume volume, {
  required String seriesId,
  required int number,
}) => volume.id == volume.isbn
    ? replacedByScan(
        volumes,
        seriesId: seriesId,
        number: number,
        scannedId: volume.id,
      )
    : const [];

/// Vrai quand [volume], rangé au numéro [number] de [seriesId], y
/// rejoindrait un autre exemplaire, un de ceux de [volumes] qu'il ne remplace
/// pas ([replacedBy]) : ce serait une deuxième édition.
bool wouldDuplicate(
  List<Volume> volumes,
  Volume volume, {
  required String seriesId,
  required int number,
}) {
  final replaced = replacedBy(
    volumes,
    volume,
    seriesId: seriesId,
    number: number,
  ).toSet();
  return volumes.any(
    (other) =>
        other.id != volume.id &&
        other.seriesId == seriesId &&
        other.number == number &&
        !replaced.contains(other.id),
  );
}
