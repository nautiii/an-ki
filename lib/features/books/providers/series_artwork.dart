import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/anilist_catalog.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/series_artwork.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cherche chez AniList l'image des séries qui n'en ont pas
/// ([seriesToIllustrate]) et la garde sur la série (`artwork`), pour
/// qu'elle se lise hors ligne et ne soit plus redemandée (D15).
///
/// Une passe à l'ouverture de l'étagère, en silence : la première erreur de
/// réseau l'arrête, les échecs d'écriture sont tus (rien n'a été demandé).
class SeriesArtworkLookup extends Notifier<void> {
  /// Vrai pendant une passe.
  bool _running = false;

  /// Séries (id, nom) déjà cherchées par cette instance : une écriture
  /// refusée (hors ligne, règles) ne relance pas la recherche à chaque retour
  /// dans l'app ; un renommage, si.
  final _looked = <(String, String)>{};

  @override
  void build() {
    // Une autre session repart de zéro.
    ref.watch(currentUidProvider);
    _looked.clear();
    ref.listen(bookSeriesProvider, (_, _) {});
  }

  /// Cherche l'image des séries dues, une à la fois, et écrit la réponse
  /// sans l'attendre. Une seule passe à la fois.
  Future<void> illustrateMissing() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || _running) return;
    _running = true;
    try {
      final List<Series> series;
      try {
        series = await ref.read(bookSeriesProvider.future);
      } on Object {
        return;
      }
      if (!ref.mounted) return;
      final now = ref.read(clockProvider)();
      final due = seriesToIllustrate([
        for (final one in series)
          if (!_looked.contains((one.id, one.name))) one,
      ], now);
      for (final one in due) {
        final List<ArtworkCandidate> candidates;
        try {
          candidates = await ref
              .read(aniListCatalogProvider)
              .searchManga(one.name);
        } on BookFailure {
          return;
        }
        if (!ref.mounted || ref.read(currentUidProvider) != uid) return;
        _looked.add((one.id, one.name));
        // La série a pu être renommée, fusionnée ou supprimée pendant la
        // recherche : rien n'est écrit sur ce qui a changé.
        final fresh = ref
            .read(bookSeriesProvider)
            .value
            ?.where((s) => s.id == one.id)
            .firstOrNull;
        if (fresh == null || fresh.name != one.name) continue;
        final artwork = SeriesArtwork(
          url: matchArtwork(fresh, candidates),
          forName: fresh.name,
          checkedAt: now,
        );
        unawaited(
          _quietly(
            ref
                .read(bookshelfRepositoryProvider)
                .setSeriesArtwork(uid, one.id, artwork),
          ),
        );
      }
    } finally {
      _running = false;
    }
  }
}

/// [write], ses échecs ignorés.
Future<void> _quietly(Future<void> write) async {
  try {
    await write;
  } on Object {
    // Une recherche que personne n'a demandée ne dérange pas.
  }
}

final seriesArtworkLookupProvider =
    NotifierProvider.autoDispose<SeriesArtworkLookup, void>(
      SeriesArtworkLookup.new,
    );
