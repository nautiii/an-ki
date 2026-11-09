import 'package:an_ki/features/books/data/bnf_catalog.dart';
import 'package:an_ki/features/books/data/google_books_catalog.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
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
/// [identifyVolume] fusionne leurs réponses, la BnF d'abord.
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
