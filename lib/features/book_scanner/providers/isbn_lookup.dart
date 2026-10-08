import 'dart:async';

import 'package:an_ki/features/book_scanner/data/models/book_model.dart';
import 'package:an_ki/features/book_scanner/data/repositories/book_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Recherche d'un livre par ISBN (Google Books) : réseau requis, le résultat
/// pilote l'écran du scanner.
///
/// État : `AsyncLoading` pendant la recherche, puis le livre trouvé (null
/// s'il est inconnu) ou l'erreur. L'écran filtre lui-même les scans qui
/// arrivent pendant une recherche.
class IsbnLookup extends AsyncNotifier<BookModel?> {
  @override
  FutureOr<BookModel?> build() => null;

  /// Renvoie le livre trouvé, null s'il est inconnu ; relance l'erreur (quota
  /// dépassé, réseau) pour que l'écran choisisse son message.
  Future<BookModel?> lookUp(String isbn) async {
    final repository = ref.read(bookRepositoryProvider);
    state = const AsyncLoading();
    try {
      final book = await repository.fetchBookByIsbn(isbn);
      if (ref.mounted) state = AsyncData(book);
      return book;
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final isbnLookupProvider =
    AsyncNotifierProvider.autoDispose<IsbnLookup, BookModel?>(IsbnLookup.new);
