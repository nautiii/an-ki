import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/domain/placement_suggestion.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_agenda.dart';
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

/// « À acheter » de l'étagère ([toBuyOf]) : le tome paru que chaque série
/// n'a pas, recalculé chaque jour.
final shelfToBuyProvider =
    Provider.autoDispose<AsyncValue<List<ShelfPurchase>>>((ref) {
      final today = ref.watch(todayProvider);
      return ref
          .watch(shelfProvider)
          .whenData((shelf) => toBuyOf(shelf.entries, today));
    });

/// « Prochaines sorties » de l'étagère ([upcomingReleasesOf]) : trois au
/// plus ; vide quand aucune date n'est connue (la section ne s'affiche pas).
final upcomingReleasesProvider =
    Provider.autoDispose<AsyncValue<List<UpcomingRelease>>>((ref) {
      final today = ref.watch(todayProvider);
      return ref
          .watch(shelfProvider)
          .whenData((shelf) => upcomingReleasesOf(shelf.entries, today));
    });

/// Vrai quand « À classer » a au moins une suggestion à faire : sa phrase
/// d'introduction ne promet rien qui n'est pas là (tomes sans titre).
final inboxHasSuggestionProvider = Provider.autoDispose<bool>((ref) {
  final shelf = ref.watch(shelfProvider).value;
  if (shelf == null) return false;
  return shelf.unclassified.any(
    (volume) => suggestPlacement(volume, shelf.entries) != null,
  );
});

/// Où « À classer » propose de ranger le tome [volumeId]
/// ([suggestPlacement]) ; null tant que l'étagère n'est pas lue, pour un
/// tome sans titre ou qui n'est plus à classer.
final placementSuggestionProvider = Provider.autoDispose
    .family<PlacementSuggestion?, String>((ref, volumeId) {
      final shelf = ref.watch(shelfProvider).value;
      if (shelf == null) return null;
      final volume = shelf.unclassified
          .where((volume) => volume.id == volumeId)
          .firstOrNull;
      return volume == null ? null : suggestPlacement(volume, shelf.entries);
    });
