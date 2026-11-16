import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_search.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_backfill.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Texte de la recherche de l'étagère ; vide à chaque changement de session
/// et quand l'onglet est démonté (module désactivé).
class ShelfSearch extends Notifier<String> {
  @override
  String build() {
    ref.watch(currentUidProvider);
    return '';
  }

  void update(String query) => state = query;
}

final shelfSearchProvider = NotifierProvider.autoDispose<ShelfSearch, String>(
  ShelfSearch.new,
);

/// Les séries montrées par l'étagère : celles dont le nom contient la
/// recherche, de A à Z ([searchShelf]).
final shelfSeriesListProvider =
    Provider.autoDispose<AsyncValue<List<ShelfEntry>>>((ref) {
      final query = ref.watch(shelfSearchProvider);
      return ref
          .watch(shelfProvider)
          .whenData((shelf) => searchShelf(shelf.entries, query));
    });

/// La série [seriesId] de l'étagère, pour sa page : chargement et erreur de
/// l'étagère tels quels, puis l'entrée, ou null si elle n'y est pas
/// (supprimée, fusionnée, en attente d'effacement, ou d'un autre compte).
final seriesEntryProvider = Provider.autoDispose
    .family<AsyncValue<ShelfEntry?>, String>(
      (ref, seriesId) => ref
          .watch(shelfProvider)
          .whenData(
            (shelf) => shelf.entries
                .where((entry) => entry.series.id == seriesId)
                .firstOrNull,
          ),
    );

/// Le tome [volumeId], pour sa feuille : suit l'étagère (un classement
/// change sa série sous les yeux) ; null une fois retiré.
final volumeByIdProvider = Provider.autoDispose
    .family<AsyncValue<Volume?>, String>(
      (ref, volumeId) => ref
          .watch(shelfProvider)
          .whenData(
            (shelf) => [
              for (final entry in shelf.entries) ...entry.volumes,
              ...shelf.unclassified,
            ].where((volume) => volume.id == volumeId).firstOrNull,
          ),
    );

/// Les numéros d'avant le tome [volumeId] que sa série n'a pas
/// ([missingBefore]), pour « J'ai aussi les tomes 1 à 4 » ; vide pour un
/// tome à classer, ou tant que l'étagère n'est pas lue.
final missingPreviousProvider = Provider.autoDispose.family<List<int>, String>((
  ref,
  volumeId,
) {
  final shelf = ref.watch(shelfProvider).value;
  if (shelf == null) return const [];
  for (final entry in shelf.entries) {
    for (final volume in entry.volumes) {
      if (volume.id == volumeId) return missingBefore(entry, volume.number!);
    }
  }
  return const [];
});
