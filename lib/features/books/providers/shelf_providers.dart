import 'package:an_ki/core/providers/pending_ids.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Séries de l'utilisateur courant, en temps réel ; liste vide hors session.
/// Dérivé de [currentUidProvider] : l'abonnement suit la session.
final bookSeriesProvider = StreamProvider.autoDispose<List<Series>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(bookshelfRepositoryProvider).watchSeries(uid);
});

/// Tomes de l'utilisateur courant, en temps réel ; liste vide hors session.
final bookVolumesProvider = StreamProvider.autoDispose<List<Volume>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(bookshelfRepositoryProvider).watchVolumes(uid);
});

/// Séries supprimées ou fusionnées mais encore rattrapables (« Annuler ») :
/// masquées de l'étagère avec leurs tomes ([PendingIds]).
final pendingSeriesRemovalsProvider = NotifierProvider<PendingIds, Set<String>>(
  () => PendingIds(currentUidProvider),
);

/// Tomes retirés mais encore rattrapables : masqués de l'étagère.
final pendingVolumeRemovalsProvider = NotifierProvider<PendingIds, Set<String>>(
  () => PendingIds(currentUidProvider),
);

/// L'étagère ([shelfOf]) des deux flux, sans ce qui attend son effacement :
/// une série en attente disparaît avec ses tomes rangés (ceux qu'elle porte
/// sans numéro valable restent « à classer », comme son effacement les
/// laisse) ; en chargement tant que l'un des flux n'a rien donné, en erreur
/// dès que l'un d'eux échoue, relance en cours comprise.
final shelfProvider = Provider.autoDispose<AsyncValue<Shelf>>((ref) {
  final series = ref.watch(bookSeriesProvider);
  final volumes = ref.watch(bookVolumesProvider);
  // L'erreur d'abord, même pendant une relance automatique (le flux est
  // alors « en chargement » avec son erreur et sa liste du cache) : une
  // lecture refusée ne doit pas passer pour une étagère vide.
  for (final stream in [series, volumes]) {
    if (stream.hasError) return AsyncError(stream.error!, stream.stackTrace!);
  }
  final hiddenSeries = ref.watch(pendingSeriesRemovalsProvider);
  final hiddenVolumes = ref.watch(pendingVolumeRemovalsProvider);
  return switch ((series.value, volumes.value)) {
    (final s?, final v?) => AsyncData(
      _withoutPending(
        shelfOf(s, [
          for (final volume in v)
            if (!hiddenVolumes.contains(volume.id)) volume,
        ]),
        hiddenSeries,
      ),
    ),
    _ => const AsyncLoading(),
  };
});

/// [shelf] sans les entrées des séries [hidden].
Shelf _withoutPending(Shelf shelf, Set<String> hidden) => hidden.isEmpty
    ? shelf
    : Shelf(
        entries: [
          for (final entry in shelf.entries)
            if (!hidden.contains(entry.series.id)) entry,
        ],
        unclassified: shelf.unclassified,
      );
