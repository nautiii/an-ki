import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/isbn.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/series_key.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/domain/volume_placement.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/providers/volume_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Écritures sur l'étagère de l'utilisateur courant (ViewModel des actions) :
/// ajout d'un tome scanné, complétion des tomes en attente, corrections.
///
/// État : `AsyncLoading` pendant une écriture, puis `AsyncData` ou
/// `AsyncError` ([ShelfFailure]). Écritures optimistes : Firestore les
/// applique au cache local et les flux de l'étagère suivent aussitôt ; l'UI
/// n'attend pas, elle écoute ce provider pour signaler un échec. Hors
/// session, rien n'est écrit.
class ShelfEditor extends AsyncNotifier<void> {
  /// Séries créées par cet éditeur, par clé : deux scans d'une même nouvelle
  /// série, coup sur coup, ne la créent qu'une fois, même avant que le flux
  /// des séries ne la montre.
  final _createdSeries = <String, Series>{};

  /// Vrai pendant une passe de [completePending].
  bool _completing = false;

  @override
  FutureOr<void> build() {
    // Une autre session repart de zéro.
    ref.watch(currentUidProvider);
    _createdSeries.clear();
    // L'éditeur range d'après l'étagère : ses flux restent en vie avec lui,
    // même sans écran qui les regarde (sinon chaque scan créerait sa série).
    ref
      ..listen(bookSeriesProvider, (_, _) {})
      ..listen(bookVolumesProvider, (_, _) {});
  }

  /// Ajoute le tome scanné [scanned] (id = ISBN). Déjà identifié par l'écran
  /// ([identified]), il est écrit complet aussitôt, sans rien attendre ;
  /// sinon il est écrit aussitôt en attente, puis complété par une recherche
  /// ([VolumeLookup]) :
  /// - trouvé : rangé dans la série de même clé, ou une nouvelle série
  ///   (confiance moyenne ou haute), sinon « à classer » ;
  /// - inconnu des catalogues : `notFound` ;
  /// - réseau, quota ou panne : il reste en attente ([completePending]).
  ///
  /// Un tome déjà trouvé n'est pas réécrit : son classement reste. Un ISBN
  /// dont la clé de contrôle est fausse : [ShelfFailure.invalidIsbn].
  Future<void> addScanned(
    String scanned, {
    IdentifiedVolume? identified,
  }) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final isbn = normalizeIsbn(scanned);
    if (isbn == null) {
      state = AsyncError(ShelfFailure.invalidIsbn, StackTrace.current);
      return;
    }
    final existing = _volumes().where((v) => v.id == isbn).firstOrNull;
    if (existing?.lookup == LookupState.found) return;

    final repository = ref.read(bookshelfRepositoryProvider);
    final writes = <Future<AsyncValue<void>>>[];
    final volume =
        existing ??
        Volume(
          id: isbn,
          isbn: isbn,
          title: '',
          authors: const [],
          lookup: LookupState.pending,
          addedAt: ref.read(clockProvider)(),
        );
    state = const AsyncLoading();
    // Écritures lancées avant tout `await` : elles partent même si l'écran
    // libère l'éditeur juste après (feuille fermée).
    final _Completion? completion;
    if (identified != null) {
      completion = _completedWith(uid, volume, identified);
    } else {
      if (existing == null) {
        writes.add(
          AsyncValue.guard(() => repository.saveScannedVolume(uid, volume)),
        );
      }
      final result = await _lookedUp(uid, volume, written: existing == null);
      if (!ref.mounted) return;
      completion = result.completion;
    }
    if (completion != null) writes.add(_save(uid, completion));
    await _settle(writes);
  }

  /// Complète les tomes en attente (scannés hors ligne) : une recherche par
  /// tome, dans l'ordre ; la première erreur de réseau ou de quota arrête la
  /// passe sans rien marquer introuvable. Une seule passe à la fois.
  Future<void> completePending() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || _completing) return;
    final pending = [
      for (final volume in _volumes())
        if (volume.lookup == LookupState.pending && volume.isbn != null) volume,
    ];
    if (pending.isEmpty) return;
    _completing = true;
    final writes = <Future<AsyncValue<void>>>[];
    state = const AsyncLoading();
    try {
      for (final volume in pending) {
        final result = await _lookedUp(uid, volume);
        if (!ref.mounted) return;
        if (!result.ok) break;
        if (result.completion case final completion?) {
          writes.add(_save(uid, completion));
        }
      }
    } finally {
      _completing = false;
    }
    await _settle(writes);
  }

  // --- Corrections ---

  /// Range le tome [volumeId] dans [seriesId] au numéro [number] ; sans série,
  /// il redevient « à classer » (et perd son numéro).
  Future<void> classify(String volumeId, {String? seriesId, int? number}) =>
      _write(
        (repository, uid) => repository.classifyVolume(
          uid,
          volumeId,
          seriesId: seriesId,
          number: seriesId == null ? null : number,
        ),
      );

  Future<void> removeVolume(String volumeId) =>
      _write((repository, uid) => repository.deleteVolume(uid, volumeId));

  /// Crée la série [name] et renvoie son id aussitôt (hors ligne compris) ;
  /// null pour un nom vide ou hors session.
  String? createSeries(String name) {
    final uid = ref.read(currentUidProvider);
    final trimmed = name.trim();
    final key = seriesKey(trimmed);
    if (uid == null || key.isEmpty) return null;
    final repository = ref.read(bookshelfRepositoryProvider);
    final series = Series(
      id: repository.newSeriesId(uid),
      name: trimmed,
      keys: [key],
      complete: false,
    );
    _createdSeries[key] = series;
    final now = ref.read(clockProvider)();
    unawaited(
      _write(
        (repository, uid) =>
            repository.createSeries(uid, series, createdAt: now),
      ),
    );
    return series.id;
  }

  /// Renomme la série [seriesId] ; son ancien nom reste une clé. Un nom vide
  /// ne change rien.
  Future<void> renameSeries(String seriesId, String name) async {
    final trimmed = name.trim();
    final key = seriesKey(trimmed);
    if (key.isEmpty) return;
    await _write(
      (repository, uid) =>
          repository.renameSeries(uid, seriesId, name: trimmed, key: key),
    );
  }

  /// Fusionne la série [sourceId] dans [targetId] : ses tomes et ses clés
  /// passent dans la cible, la source disparaît.
  Future<void> mergeSeries({
    required String sourceId,
    required String targetId,
  }) {
    final source = _series().where((s) => s.id == sourceId).firstOrNull;
    return _write(
      (repository, uid) => repository.mergeSeries(
        uid,
        sourceId: sourceId,
        targetId: targetId,
        keys: source == null ? const [] : keysOf(source),
      ),
    );
  }

  Future<void> setComplete(String seriesId, {required bool complete}) => _write(
    (repository, uid) =>
        repository.setSeriesComplete(uid, seriesId, complete: complete),
  );

  /// Ce qu'on sait du prochain tome de [seriesId] ; null l'efface.
  Future<void> setNext(String seriesId, NextVolumeInfo? next) => _write(
    (repository, uid) => repository.setNextVolume(uid, seriesId, next),
  );

  // --- Interne ---

  List<Volume> _volumes() => ref.read(bookVolumesProvider).value ?? const [];

  List<Series> _series() => [
    ...?ref.read(bookSeriesProvider).value,
    ..._createdSeries.values,
  ];

  /// Recherche les infos de [volume]. `ok` faux quand elle a échoué (réseau,
  /// quota : le tome reste en attente) ou que l'éditeur n'est plus monté ;
  /// sinon ce qu'il faut écrire : `notFound` quand les catalogues ne le
  /// connaissent pas, rien quand le tome a été retiré ou trouvé entre-temps.
  /// [written] : le tome vient d'être écrit, même si le flux ne le montre
  /// pas encore.
  Future<({bool ok, _Completion? completion})> _lookedUp(
    String uid,
    Volume volume, {
    bool written = false,
  }) async {
    final lookup = ref.read(volumeLookupProvider);
    final IdentifiedVolume? found;
    try {
      found = await lookup.lookUp(volume.isbn!);
    } on BookFailure {
      return (ok: false, completion: null);
    }
    if (!ref.mounted) return (ok: false, completion: null);
    // Relu après l'attente : pendant la recherche, l'utilisateur a pu retirer
    // le tome ou le ranger ; la complétion ne le recrée ni ne le déplace.
    final known = ref.read(bookVolumesProvider).value;
    final current = known == null
        ? volume
        : known.where((v) => v.id == volume.id).firstOrNull ??
              (written ? volume : null);
    if (current == null || current.lookup == LookupState.found) {
      return (ok: true, completion: null);
    }
    if (found == null) {
      return (
        ok: true,
        completion: (
          volume: _withLookup(current, LookupState.notFound),
          newSeries: null,
        ),
      );
    }
    return (ok: true, completion: _completedWith(uid, current, found));
  }

  /// [volume] complété par [found] : rangé dans sa série, ou « à classer »,
  /// avec la série neuve à créer s'il en faut une. Un tome déjà rangé garde sa
  /// série et son numéro.
  _Completion _completedWith(
    String uid,
    Volume volume,
    IdentifiedVolume found,
  ) {
    final repository = ref.read(bookshelfRepositoryProvider);
    final classified = volume.seriesId != null;
    final placement = classified
        ? null
        : placeVolume(
            found.guess,
            _series(),
            newSeriesId: () => repository.newSeriesId(uid),
          );
    final newSeries = placement != null && placement.isNew
        ? placement.series
        : null;
    if (newSeries != null) _createdSeries[newSeries.keys.first] = newSeries;
    final metadata = found.metadata;
    return (
      volume: Volume(
        id: volume.id,
        seriesId: classified ? volume.seriesId : placement?.series.id,
        number: classified ? volume.number : placement?.number,
        isbn: volume.isbn,
        title: volumeTitleOf(metadata),
        authors: metadata.authors,
        imageUrl: metadata.imageUrl,
        publisher: metadata.publisher,
        publishedDate: metadata.publishedDate,
        lookup: LookupState.found,
        addedAt: volume.addedAt,
      ),
      newSeries: newSeries,
    );
  }

  /// Écrit [completion] : le tome et sa série neuve dans un même lot. Refusée,
  /// la série neuve est oubliée : les scans suivants ne s'y rangent pas.
  Future<AsyncValue<void>> _save(String uid, _Completion completion) async {
    final repository = ref.read(bookshelfRepositoryProvider);
    final newSeries = completion.newSeries;
    final result = await AsyncValue.guard(
      () => repository.saveScannedVolume(
        uid,
        completion.volume,
        withSeries: newSeries == null
            ? null
            : (series: newSeries, createdAt: ref.read(clockProvider)()),
      ),
    );
    if (result.hasError && newSeries != null) {
      _createdSeries.remove(newSeries.keys.first);
    }
    return result;
  }

  /// Attend les écritures lancées ([writes], déjà gardées : aucune erreur
  /// n'échappe) et publie la première erreur, sinon le succès.
  Future<void> _settle(List<Future<AsyncValue<void>>> writes) async {
    final results = await Future.wait(writes);
    if (!ref.mounted) return;
    state = results.firstWhere(
      (result) => result.hasError,
      orElse: () => const AsyncData(null),
    );
  }

  Future<void> _write(
    Future<void> Function(BookshelfRepository repository, String uid) write,
  ) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final repository = ref.read(bookshelfRepositoryProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => write(repository, uid));
    if (ref.mounted) state = result;
  }
}

/// Un tome à écrire, et la série neuve qu'il ouvre.
typedef _Completion = ({Volume volume, Series? newSeries});

Volume _withLookup(Volume volume, LookupState lookup) => Volume(
  id: volume.id,
  seriesId: volume.seriesId,
  number: volume.number,
  isbn: volume.isbn,
  title: volume.title,
  authors: volume.authors,
  imageUrl: volume.imageUrl,
  publisher: volume.publisher,
  publishedDate: volume.publishedDate,
  lookup: lookup,
  addedAt: volume.addedAt,
);

final shelfEditorProvider =
    AsyncNotifierProvider.autoDispose<ShelfEditor, void>(ShelfEditor.new);
