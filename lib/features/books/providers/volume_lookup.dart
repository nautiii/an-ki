import 'package:an_ki/features/books/data/bnf_catalog.dart';
import 'package:an_ki/features/books/data/google_books_catalog.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/volume_backfill.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final volumeLookupProvider = Provider<VolumeLookup>(
  (ref) => VolumeLookup(
    bnf: ref.watch(bnfCatalogProvider),
    google: ref.watch(googleBooksCatalogProvider),
  ),
);

/// Identifie un livre par son ISBN : la BnF (série et numéro structurés) et
/// Google Books (couverture, tomes récents) sont interrogés ensemble, puis
/// [identifyVolume] fusionne leurs réponses, la BnF d'abord. Trouve aussi un
/// tome sans ISBN par sa série et son numéro ([findByNumber]).
///
/// Sans état : le scanner et le complétant de l'étagère l'appellent.
class VolumeLookup {
  VolumeLookup({required this._bnf, required this._google});

  final BnfCatalog _bnf;
  final GoogleBooksCatalog _google;

  /// Le livre [isbn] (un ISBN-13 normalisé) ; null quand les deux catalogues
  /// ont répondu sans le connaître.
  ///
  /// Une source en échec est ignorée si l'autre connaît le livre. Sinon,
  /// l'échec remonte, pour que le livre reste « en attente » plutôt
  /// qu'« introuvable » : [BookFailure.network] dès qu'une source était
  /// injoignable, puis [BookFailure.quotaExceeded], puis
  /// [BookFailure.unavailable].
  Future<IdentifiedVolume?> lookUp(String isbn) async {
    final (bnf, google) = await (
      _ask(() => _bnf.fetchByIsbn(isbn)),
      _ask(() => _google.fetchByIsbn(isbn)),
    ).wait;
    if (bnf.metadata != null || google.metadata != null) {
      return identifyVolume(isbn, bnf: bnf.metadata, google: google.metadata);
    }
    final failures = [?bnf.failure, ?google.failure];
    if (failures.isEmpty) return null;
    final failure = failures.contains(BookFailure.network)
        ? BookFailure.network
        : failures.contains(BookFailure.quotaExceeded)
        ? BookFailure.quotaExceeded
        : BookFailure.unavailable;
    final stack = failure == bnf.failure ? bnf.stack : google.stack;
    Error.throwWithStackTrace(failure, stack ?? StackTrace.current);
  }

  /// La notice du tome [number] de la série [seriesName] (clés [keys]), pour
  /// un tome ajouté sans ISBN : la BnF d'abord, puis Google Books quand elle
  /// n'en a pas et que [askGoogle] le permet ; [backfillRecordOf] choisit,
  /// l'éditeur [publisher] d'abord.
  ///
  /// `settled` vrai quand la réponse est définitive (une notice, ou aucune
  /// des sources interrogées n'en a) ; faux quand Google, nécessaire, n'a pas
  /// été interrogé ou n'a pas pu répondre : le tome reste à chercher. Un échec
  /// de la BnF remonte ([BookFailure]).
  Future<({BookMetadata? record, bool settled})> findByNumber(
    String seriesName,
    Set<String> keys,
    int number, {
    String? publisher,
    bool askGoogle = true,
  }) async {
    final fromBnf = backfillRecordOf(
      keys,
      number,
      await _bnf.searchVolume(seriesName, number),
      publisher: publisher,
    );
    if (fromBnf != null) return (record: fromBnf, settled: true);
    if (!askGoogle) return (record: null, settled: false);
    final List<BookMetadata> google;
    try {
      google = await _google.searchVolume(seriesName, number);
    } on BookFailure {
      return (record: null, settled: false);
    }
    return (
      record: backfillRecordOf(keys, number, google, publisher: publisher),
      settled: true,
    );
  }
}

typedef _Answer = ({
  BookMetadata? metadata,
  BookFailure? failure,
  StackTrace? stack,
});

Future<_Answer> _ask(Future<BookMetadata?> Function() fetch) async {
  try {
    return (metadata: await fetch(), failure: null, stack: null);
  } on BookFailure catch (failure, stack) {
    return (metadata: null, failure: failure, stack: stack);
  }
}
