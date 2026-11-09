import 'dart:async';

import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/providers/volume_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Recherche d'un livre scanné ([VolumeLookup] : BnF et Google Books) :
/// réseau requis, le résultat pilote l'écran du scanner.
///
/// État : `AsyncLoading` pendant la recherche, puis le livre identifié (null
/// s'il est inconnu) ou l'erreur. L'écran filtre lui-même les scans qui
/// arrivent pendant une recherche.
class IsbnLookup extends AsyncNotifier<IdentifiedVolume?> {
  @override
  FutureOr<IdentifiedVolume?> build() => null;

  /// Renvoie le livre identifié, null s'il est inconnu ; relance l'erreur
  /// (`BookFailure` : quota dépassé, réseau) pour que l'écran choisisse son
  /// message.
  Future<IdentifiedVolume?> lookUp(String isbn) async {
    final lookup = ref.read(volumeLookupProvider);
    state = const AsyncLoading();
    try {
      final found = await lookup.lookUp(isbn);
      if (ref.mounted) state = AsyncData(found);
      return found;
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final isbnLookupProvider =
    AsyncNotifierProvider.autoDispose<IsbnLookup, IdentifiedVolume?>(
      IsbnLookup.new,
    );
