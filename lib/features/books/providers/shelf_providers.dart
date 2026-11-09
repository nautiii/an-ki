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

/// L'étagère ([shelfOf]) des deux flux : en chargement tant que l'un d'eux
/// n'a rien donné, en erreur dès que l'un d'eux échoue.
final shelfProvider = Provider.autoDispose<AsyncValue<Shelf>>((ref) {
  final series = ref.watch(bookSeriesProvider);
  final volumes = ref.watch(bookVolumesProvider);
  if (series case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (volumes case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  return switch ((series.value, volumes.value)) {
    (final s?, final v?) => AsyncData(shelfOf(s, v)),
    _ => const AsyncLoading(),
  };
});
