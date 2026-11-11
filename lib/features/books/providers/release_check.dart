import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bnf_catalog.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/data/google_books_catalog.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/next_volume_status.dart';
import 'package:an_ki/features/books/domain/release_check.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Vérifie à la BnF, puis chez Google Books quand la BnF ne date pas le tome
/// ([needsGoogleCheck]), ce qu'on sait du prochain tome des séries (D14) et
/// le garde sur la série (`next`), pour qu'il se lise hors ligne.
///
/// - [checkStale] : à l'ouverture de l'étagère, en silence, les séries dues
///   ([entriesToCheck]) ; la première erreur de réseau arrête la passe.
/// - [checkSeries] : « tirer pour actualiser » sur une série ; l'état publie
///   `AsyncLoading`, puis `AsyncData` ou `AsyncError` ([BookFailure] pour la
///   recherche BnF, `ShelfFailure` pour l'écriture).
///
/// Google Books ne fait que compléter : son échec (quota, réseau) laisse ce
/// que dit la BnF s'écrire, sans erreur publiée.
class ReleaseCheck extends AsyncNotifier<void> {
  /// Vrai pendant une passe de [checkStale].
  bool _checking = false;

  /// Séries déjà vérifiées par cette instance : une écriture refusée (hors
  /// ligne, règles) ne relance pas la recherche à chaque retour dans l'app.
  final _checked = <String>{};

  @override
  FutureOr<void> build() {
    // Une autre session repart de zéro.
    ref.watch(currentUidProvider);
    _checked.clear();
    ref
      ..listen(bookSeriesProvider, (_, _) {})
      ..listen(bookVolumesProvider, (_, _) {});
  }

  /// Vérifie les séries dues, une recherche à la fois, et écrit ce qui a
  /// changé sans l'attendre. Une seule passe à la fois ; une étagère
  /// illisible, ou la première erreur d'un catalogue, l'arrête sans rien
  /// écrire de plus. Les échecs d'écriture sont tus : rien n'a été demandé.
  Future<void> checkStale() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || _checking) return;
    _checking = true;
    try {
      try {
        await (
          ref.read(bookSeriesProvider.future),
          ref.read(bookVolumesProvider.future),
        ).wait;
      } on Object {
        return;
      }
      if (!ref.mounted) return;
      final shelf = ref.read(shelfProvider).value;
      if (shelf == null) return;
      final now = ref.read(clockProvider)();
      // Google en échec (quota, souvent) n'est plus interrogé de la passe.
      var googleDown = false;
      final due = entriesToCheck([
        for (final entry in shelf.entries)
          if (!_checked.contains(entry.series.id)) entry,
      ], now);
      for (final entry in due) {
        final number = upcomingVolumeNumber(entry);
        if (number == null) continue;
        final List<BookMetadata> records;
        try {
          records = await ref
              .read(bnfCatalogProvider)
              .searchVolume(entry.series.name, number);
        } on BookFailure {
          return;
        }
        if (!ref.mounted || ref.read(currentUidProvider) != uid) return;
        final googleNeeded = needsGoogleCheck(entry, number, records, now);
        List<BookMetadata>? google;
        if (googleNeeded && !googleDown) {
          google = await _searchGoogle(entry.series.name, number);
          googleDown = google == null;
          if (!ref.mounted || ref.read(currentUidProvider) != uid) return;
        }
        // L'étagère a pu bouger pendant la recherche (une date saisie, un
        // tome scanné, une série fusionnée ou supprimée) : rien n'est écrit
        // sur ce qui a changé.
        final fresh = _entry(entry.series.id);
        if (fresh == null ||
            upcomingVolumeNumber(fresh) != number ||
            fresh.series.next != entry.series.next) {
          _checked.add(entry.series.id);
          continue;
        }
        final info = checkedRelease(
          fresh,
          number,
          records,
          now,
          google: google,
        );
        // Google n'a pu répondre : une réponse sans date n'est pas écrite,
        // elle repousserait d'une semaine ce que Google aurait pu dire. La
        // série sera revue à la prochaine passe.
        if (googleNeeded &&
            google == null &&
            (info == null ||
                (info.date == null && info.status != ReleaseStatus.released))) {
          continue;
        }
        _checked.add(entry.series.id);
        if (info != null) {
          unawaited(_quietly(_write(uid, entry.series.id, info)));
        }
      }
    } finally {
      _checking = false;
    }
  }

  /// Vérifie la série [seriesId] tout de suite, qu'elle soit due ou non
  /// ([checkedRelease] : une notice datée au jour ou au mois remplace même
  /// une date saisie). Rien pour une série inconnue ou close.
  Future<void> checkSeries(String seriesId) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || state.isLoading) return;
    final entry = _entry(seriesId);
    final number = entry == null ? null : upcomingVolumeNumber(entry);
    if (entry == null || number == null) return;
    state = const AsyncLoading();
    final List<BookMetadata> records;
    try {
      records = await ref
          .read(bnfCatalogProvider)
          .searchVolume(entry.series.name, number);
    } on BookFailure catch (failure, stack) {
      if (ref.mounted) state = AsyncError(failure, stack);
      return;
    }
    if (!ref.mounted || ref.read(currentUidProvider) != uid) return;
    final now = ref.read(clockProvider)();
    final google = needsGoogleCheck(entry, number, records, now)
        ? await _searchGoogle(entry.series.name, number)
        : null;
    if (!ref.mounted || ref.read(currentUidProvider) != uid) return;
    // L'étagère a pu bouger pendant la recherche (un tome scanné).
    final fresh = _entry(seriesId);
    if (fresh == null || upcomingVolumeNumber(fresh) != number) {
      state = const AsyncData(null);
      return;
    }
    _checked.add(seriesId);
    state = const AsyncData(null);
    if (checkedRelease(fresh, number, records, now, google: google)
        case final info?) {
      // Pas attendue : hors ligne, l'écriture ne se résout qu'au retour du
      // réseau. Un refus s'affiche quand il arrive.
      unawaited(
        _write(uid, seriesId, info).then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            if (ref.mounted) state = AsyncError(error, stack);
          },
        ),
      );
    }
  }

  ShelfEntry? _entry(String seriesId) => ref
      .read(shelfProvider)
      .value
      ?.entries
      .where((entry) => entry.series.id == seriesId)
      .firstOrNull;

  /// Volumes de Google Books pour ce tome ; null quand Google n'a pu
  /// répondre (quota, réseau, réponse illisible).
  Future<List<BookMetadata>?> _searchGoogle(String name, int number) async {
    try {
      return await ref
          .read(googleBooksCatalogProvider)
          .searchVolume(name, number);
    } on BookFailure {
      return null;
    }
  }

  Future<void> _write(String uid, String seriesId, NextVolumeInfo info) =>
      ref.read(bookshelfRepositoryProvider).setNextVolume(uid, seriesId, info);
}

/// [write], ses échecs ignorés.
Future<void> _quietly(Future<void> write) async {
  try {
    await write;
  } on Object {
    // Une vérification que personne n'a demandée ne dérange pas.
  }
}

final releaseCheckProvider =
    AsyncNotifierProvider.autoDispose<ReleaseCheck, void>(ReleaseCheck.new);
