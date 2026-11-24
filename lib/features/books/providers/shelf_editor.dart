import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/isbn.dart';
import 'package:an_ki/features/books/domain/placement_suggestion.dart';
import 'package:an_ki/features/books/domain/release_check.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/series_key.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_backfill.dart';
import 'package:an_ki/features/books/domain/volume_identification.dart';
import 'package:an_ki/features/books/domain/volume_number.dart';
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

  /// Vrai quand des tomes sont arrivés pendant une passe : elle en refait une.
  bool _again = false;

  /// Tomes sans ISBN ajoutés par cet éditeur, à compléter, tant que le flux
  /// des tomes ne les montre pas encore (l'écriture vient de partir).
  final _queued = <String, Volume>{};

  /// Tomes laissés en attente faute de Google : cherchés après les autres,
  /// pour qu'ils ne bloquent pas la file à chaque ouverture.
  final _waitingGoogle = <String>{};

  @override
  FutureOr<void> build() {
    // Une autre session repart de zéro.
    ref.watch(currentUidProvider);
    _createdSeries.clear();
    _queued.clear();
    _waitingGoogle.clear();
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
      if (_stale(uid)) return;
      completion = result.completion;
    }
    if (completion != null) writes.add(_save(uid, completion));
    await _settle(writes);
  }

  /// Complète les tomes en attente : d'abord les scannés hors ligne (une
  /// recherche par ISBN), puis les tomes ajoutés sans ISBN (« les tomes
  /// précédents », une série ajoutée à la main), par leur série et leur
  /// numéro, [backfillsPerPass] au plus par appel. La première erreur de
  /// réseau ou de quota arrête la passe sans rien marquer introuvable ;
  /// Google en échec laisse seulement en attente les tomes que la BnF ne
  /// connaît pas, cherchés ensuite après les autres.
  ///
  /// Une seule passe à la fois : un appel pendant une passe en demande une
  /// autre à sa fin (des tomes viennent d'être ajoutés), qui ne reprend pas
  /// les tomes déjà traités (le flux peut ne pas encore montrer leurs
  /// écritures) et partage la limite de l'appel. Un changement de compte
  /// arrête tout. Attend la première lecture des tomes (un écran qui s'ouvre
  /// l'appelle aussitôt) ; une étagère illisible ne lance rien.
  Future<void> completePending() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    if (_completing) {
      _again = true;
      return;
    }
    _completing = true;
    final writes = <Future<AsyncValue<void>>>[];
    final done = <String>{};
    final budget = _Budget(backfillsPerPass);
    var started = false;
    try {
      do {
        _again = false;
        final pass = await _completionPass(uid, writes, done, budget);
        started = started || pass.started;
        if (!pass.ok) break;
      } while (_again && !_stale(uid));
    } finally {
      _completing = false;
    }
    if (started) await _settle(writes);
  }

  /// Vrai quand ce qui a été lu pour [uid] ne vaut plus : éditeur libéré,
  /// ou un autre compte connecté entre-temps (l'éditeur survit à ce
  /// changement, `ref.mounted` reste vrai).
  bool _stale(String uid) =>
      !ref.mounted || ref.read(currentUidProvider) != uid;

  /// Une passe de [completePending] ; `ok` faux quand elle s'est arrêtée
  /// (réseau, quota, éditeur libéré, autre compte, étagère illisible),
  /// `started` vrai quand elle avait des tomes à compléter. [done] : les
  /// tomes déjà traités par cet appel, passés ; chaque tome traité s'y
  /// ajoute. [budget] : les recherches par numéro qui restent à l'appel.
  Future<({bool ok, bool started})> _completionPass(
    String uid,
    List<Future<AsyncValue<void>>> writes,
    Set<String> done,
    _Budget budget,
  ) async {
    final List<Volume> volumes;
    try {
      volumes = await ref.read(bookVolumesProvider.future);
    } on Object {
      return (ok: false, started: false);
    }
    if (_stale(uid)) return (ok: false, started: false);
    final scanned = [
      for (final volume in volumes)
        if (volume.lookup == LookupState.pending &&
            volume.isbn != null &&
            !done.contains(volume.id))
          volume,
    ];
    final seen = {for (final volume in volumes) volume.id};
    _queued.removeWhere((id, _) => seen.contains(id));
    final numbered = [
      for (final volume in [...volumes, ..._queued.values])
        if (awaitsBackfill(volume) && !done.contains(volume.id)) volume,
    ]..sort(_backfillOrder);
    if (scanned.isEmpty && numbered.isEmpty) return (ok: true, started: false);
    state = const AsyncLoading();
    for (final volume in scanned) {
      done.add(volume.id);
      final result = await _lookedUp(uid, volume);
      if (_stale(uid) || !result.ok) return (ok: false, started: true);
      if (result.completion case final completion?) {
        writes.add(_save(uid, completion));
      }
    }
    var googleDown = false;
    for (final volume in numbered) {
      if (budget.left == 0) break;
      done.add(volume.id);
      // La BnF ne le connaît pas, Google ne répond pas : rien à redemander.
      if (googleDown && _waitingGoogle.contains(volume.id)) continue;
      final result = await _backfill(uid, volume, askGoogle: !googleDown);
      if (result == null) return (ok: false, started: true);
      if (result.searched) budget.left--;
      if (!result.settled) googleDown = true;
    }
    return (ok: true, started: true);
  }

  /// Ajoute à la main la série [name] avec les tomes [numbers] (une
  /// collection déjà là, sans la scanner) et renvoie son id aussitôt (hors
  /// ligne compris) ; null pour un nom vide ou hors session.
  ///
  /// Un nom dont la clé existe rejoint cette série (un ancien nom compris) ;
  /// les numéros qu'elle possède déjà ne sont pas doublés. [complete] la
  /// marque terminée ; décoché, il ne rouvre pas une série terminée.
  String? addSeriesByHand(
    String name,
    List<int> numbers, {
    required bool complete,
  }) {
    final uid = ref.read(currentUidProvider);
    final trimmed = name.trim();
    final key = seriesKey(trimmed);
    if (uid == null || key.isEmpty) return null;
    final repository = ref.read(bookshelfRepositoryProvider);
    final existing = findSeriesByKey(_visibleSeries(), key);
    final target =
        existing ??
        Series(
          id: repository.newSeriesId(uid),
          name: trimmed,
          keys: [key],
          complete: complete,
        );
    if (existing == null) _createdSeries[key] = target;
    final owned = {
      for (final volume in _volumes())
        if (volume.seriesId == target.id) ?volume.number,
    };
    final now = ref.read(clockProvider)();
    final volumes = [
      for (final number in numbers)
        if (!owned.contains(number))
          Volume(
            id: repository.newVolumeId(uid),
            seriesId: target.id,
            number: number,
            title: '',
            authors: const [],
            // Cherché ensuite par sa série et son numéro.
            lookup: LookupState.pending,
            addedAt: now,
          ),
    ];
    _queue(volumes);
    unawaited(
      _write(
        (repository, uid) => repository.addManualVolumes(
          uid,
          volumes,
          withSeries: existing == null
              ? (series: target, createdAt: now)
              : null,
          completeSeriesId: existing != null && complete && !existing.complete
              ? existing.id
              : null,
        ),
      ),
    );
    return target.id;
  }

  // --- Corrections ---

  /// Range le tome [volumeId] dans [seriesId] au numéro [number] ; sans série,
  /// il redevient « à classer » (et perd son numéro). Un tome scanné remplace
  /// ceux de ce numéro ajoutés à la main ([replacedBy]), dans le même lot.
  Future<void> classify(String volumeId, {String? seriesId, int? number}) {
    final known = [..._volumes(), ..._queued.values];
    final volume = known.where((v) => v.id == volumeId).firstOrNull;
    final replacing = switch ((volume, seriesId, number)) {
      (final volume?, final seriesId?, final number?) => replacedBy(
        known,
        volume,
        seriesId: seriesId,
        number: number,
      ),
      _ => const <String>[],
    };
    _queued.removeWhere((id, _) => replacing.contains(id));
    return _write(
      (repository, uid) => repository.classifyVolume(
        uid,
        volumeId,
        seriesId: seriesId,
        number: seriesId == null ? null : number,
        replacing: replacing,
      ),
    );
  }

  /// Retire le tome [volumeId]. [uid] : voir [_write] (écriture différée par
  /// « Annuler »).
  Future<void> removeVolume(String volumeId, {String? uid}) => _write(
    (repository, uid) => repository.deleteVolume(uid, volumeId),
    startedBy: uid,
  );

  /// « J'ai aussi les tomes précédents » : ajoute à la série du tome
  /// [volumeId] les numéros qu'elle n'a pas avant le sien
  /// ([missingBefore]), comme [addNumbers]. Renvoie leurs ids, pour
  /// « Annuler » ; vide quand il n'y a rien à ajouter (tome à classer, aucun
  /// trou avant lui) ou hors session.
  List<String> addPrevious(String volumeId) {
    final volume = _volumes().where((v) => v.id == volumeId).firstOrNull;
    final seriesId = volume?.seriesId;
    final number = volume?.number;
    if (seriesId == null || number == null) return const [];
    final entry = _entryOf(seriesId);
    if (entry == null) return const [];
    return addNumbers(seriesId, missingBefore(entry, number));
  }

  /// « Acheté », « Je les ai » : ajoute à la série [seriesId] les tomes
  /// [numbers] qu'elle n'a pas, sans ISBN et en attente, aussitôt (hors ligne
  /// compris), puis lance leur recherche par série et numéro
  /// ([completePending]). Renvoie leurs ids, pour « Annuler » ; vide quand il
  /// n'y a rien à ajouter (série inconnue, numéros déjà là ou hors de 1 à
  /// `maxVolumeNumber`) ou hors session.
  List<String> addNumbers(String seriesId, List<int> numbers) {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return const [];
    final entry = _entryOf(seriesId);
    if (entry == null) return const [];
    // Déjà possédés, ou ajoutés mais pas encore montrés par le flux (double
    // toucher, deux lignes d'une même série) : pas de doublon.
    final taken = {
      ...entry.owned,
      for (final volume in _queued.values)
        if (volume.seriesId == seriesId) ?volume.number,
    };
    final repository = ref.read(bookshelfRepositoryProvider);
    final now = ref.read(clockProvider)();
    final volumes = [
      for (final number in {...numbers})
        if (number >= 1 && number <= maxVolumeNumber && !taken.contains(number))
          Volume(
            id: repository.newVolumeId(uid),
            seriesId: seriesId,
            number: number,
            title: '',
            authors: const [],
            lookup: LookupState.pending,
            addedAt: now,
          ),
    ];
    if (volumes.isEmpty) return const [];
    _queue(volumes);
    unawaited(
      _write((repository, uid) => repository.addManualVolumes(uid, volumes)),
    );
    return [for (final volume in volumes) volume.id];
  }

  /// Accepte la proposition [suggestion] de « À classer » : range le tome
  /// [volumeId] dans sa série, ou dans celle qui porte la clé de son nom
  /// (créée entre-temps par un autre toucher), sinon dans une nouvelle série
  /// créée dans le même lot. Une série qui attend « Annuler » de sa
  /// suppression ne compte plus. Renvoie l'id de la série ; null pour un tome
  /// inconnu, un nom vide ou hors session.
  String? place(String volumeId, PlacementSuggestion suggestion) {
    final uid = ref.read(currentUidProvider);
    final volume = _volumes().where((v) => v.id == volumeId).firstOrNull;
    if (uid == null || volume == null) return null;
    final visible = _visibleSeries();
    final name = suggestion.seriesName.trim();
    final key = seriesKey(name);
    final existing =
        visible.where((s) => s.id == suggestion.series?.id).firstOrNull ??
        (key.isEmpty ? null : findSeriesByKey(visible, key));
    if (existing != null) {
      unawaited(
        classify(volumeId, seriesId: existing.id, number: suggestion.number),
      );
      return existing.id;
    }
    if (key.isEmpty) return null;
    final repository = ref.read(bookshelfRepositoryProvider);
    final series = Series(
      id: repository.newSeriesId(uid),
      name: name,
      keys: [key],
      complete: false,
    );
    _createdSeries[key] = series;
    final placed = Volume(
      id: volume.id,
      seriesId: series.id,
      number: suggestion.number,
      isbn: volume.isbn,
      title: volume.title,
      authors: volume.authors,
      imageUrl: volume.imageUrl,
      publisher: volume.publisher,
      publishedDate: volume.publishedDate,
      lookup: volume.lookup,
      addedAt: volume.addedAt,
    );
    final now = ref.read(clockProvider)();
    unawaited(
      _write(
        (repository, uid) => repository.saveScannedVolume(
          uid,
          placed,
          withSeries: (series: series, createdAt: now),
        ),
      ),
    );
    return series.id;
  }

  /// Retire les tomes [volumeIds] (« Annuler » de [addNumbers]). [uid] :
  /// voir [_write].
  Future<void> removeVolumes(List<String> volumeIds, {String? uid}) {
    _queued.removeWhere((id, _) => volumeIds.contains(id));
    return _write(
      (repository, uid) => repository.deleteVolumes(uid, volumeIds),
      startedBy: uid,
    );
  }

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
    String? uid,
  }) {
    final source = _series().where((s) => s.id == sourceId).firstOrNull;
    return _write(
      (repository, uid) => repository.mergeSeries(
        uid,
        sourceId: sourceId,
        targetId: targetId,
        keys: source == null ? const [] : keysOf(source),
      ),
      startedBy: uid,
    );
  }

  /// Supprime la série [seriesId] avec tous ses tomes.
  Future<void> deleteSeries(String seriesId, {String? uid}) => _write(
    (repository, uid) => repository.deleteSeries(uid, seriesId),
    startedBy: uid,
  );

  Future<void> setComplete(
    String seriesId, {
    required bool complete,
    String? uid,
  }) => _write(
    (repository, uid) =>
        repository.setSeriesComplete(uid, seriesId, complete: complete),
    startedBy: uid,
  );

  /// Ce qu'on sait du prochain tome de [seriesId] ; null l'efface.
  Future<void> setNext(String seriesId, NextVolumeInfo? next) => _write(
    (repository, uid) => repository.setNextVolume(uid, seriesId, next),
  );

  /// La date de sortie [date] du tome [number] de [seriesId], saisie par
  /// l'utilisateur (« date saisie par vous ») ; null l'efface, et la BnF
  /// sera de nouveau interrogée à la prochaine ouverture de l'étagère.
  Future<void> enterReleaseDate(
    String seriesId,
    int number,
    ReleaseDate? date,
  ) => setNext(
    seriesId,
    date == null
        ? null
        : enteredRelease(number, date, ref.read(clockProvider)()),
  );

  // --- Interne ---

  /// Les séries connues, sans celles dont la suppression attend « Annuler » :
  /// leurs tomes partiraient avec elles.
  List<Series> _visibleSeries() {
    final hidden = ref.read(pendingSeriesRemovalsProvider);
    return [
      for (final series in _series())
        if (!hidden.contains(series.id)) series,
    ];
  }

  /// La série [seriesId] telle que l'écran la montre : sans les tomes ni les
  /// séries qui attendent « Annuler » de leur retrait ; null quand elle n'y
  /// est pas.
  ShelfEntry? _entryOf(String seriesId) {
    final hidden = ref.read(pendingVolumeRemovalsProvider);
    return shelfOf(_visibleSeries(), [
      for (final volume in _volumes())
        if (!hidden.contains(volume.id)) volume,
    ]).entries.where((entry) => entry.series.id == seriesId).firstOrNull;
  }

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
    // Un autre compte entre-temps : rien de celui-ci ne passe à l'autre (pas
    // même une série neuve dans `_createdSeries`).
    if (_stale(uid)) return (ok: false, completion: null);
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

  /// Garde [volumes] (sans ISBN, en attente) à compléter, puis lance la
  /// recherche ; ils comptent avant même que le flux des tomes les montre.
  void _queue(List<Volume> volumes) {
    if (volumes.isEmpty) return;
    for (final volume in volumes) {
      _queued[volume.id] = volume;
    }
    unawaited(completePending());
  }

  /// Cherche [volume] (sans ISBN) par sa série et son numéro, et écrit ce
  /// qu'on en a trouvé, sans l'attendre et en silence (rien n'a été demandé :
  /// un tome retiré entre-temps fait échouer l'écriture, sans plus). Null
  /// quand la BnF n'a pas pu répondre, que l'éditeur n'est plus monté ou que
  /// le compte a changé (la passe s'arrête) ; `searched` faux quand rien n'a
  /// été demandé (tome retiré, déplacé ou complété depuis la liste de la
  /// passe) ; `settled` faux quand Google, nécessaire, n'a pas pu répondre
  /// (le tome reste en attente).
  Future<({bool searched, bool settled})?> _backfill(
    String uid,
    Volume volume, {
    required bool askGoogle,
  }) async {
    final seriesId = volume.seriesId!;
    final number = volume.number!;
    const skipped = (searched: false, settled: true);
    // Relu avant de rien demander : « Annuler », un scan qui le remplace ou
    // une série supprimée l'ont peut-être déjà retiré.
    if (!_stillAwaits(volume.id, seriesId, number)) {
      _queued.remove(volume.id);
      return skipped;
    }
    final entry = shelfOf(
      _series(),
      _volumes(),
    ).entries.where((entry) => entry.series.id == seriesId).firstOrNull;
    // Série pas encore montrée par le flux, ou supprimée : rien à chercher.
    if (entry == null) return skipped;
    final ({BookMetadata? record, bool settled}) found;
    try {
      found = await ref
          .read(volumeLookupProvider)
          .findByNumber(
            entry.series.name,
            keysOf(entry.series).toSet(),
            number,
            publisher: usualPublisherOf(entry),
            askGoogle: askGoogle,
          );
    } on BookFailure {
      return null;
    }
    if (_stale(uid)) return null;
    if (!found.settled) {
      _waitingGoogle.add(volume.id);
      return (searched: true, settled: false);
    }
    _waitingGoogle.remove(volume.id);
    // Relu après l'attente : retiré, déplacé ou renuméroté entre-temps, il
    // n'est pas complété avec la notice d'un autre tome.
    final current = _awaiting(volume.id);
    final stillAwaits = _stillAwaits(volume.id, seriesId, number);
    _queued.remove(volume.id);
    if (current != null && stillAwaits) {
      unawaited(
        AsyncValue.guard(
          () => ref
              .read(bookshelfRepositoryProvider)
              .completeVolume(uid, backfilled(current, found.record)),
        ),
      );
    }
    return (searched: true, settled: true);
  }

  /// Le tome [id] tel que l'éditeur le connaît : le flux, sinon la file.
  Volume? _awaiting(String id) =>
      _volumes().where((v) => v.id == id).firstOrNull ?? _queued[id];

  /// Vrai quand le tome [id] attend toujours sa recherche, au numéro
  /// [number] de [seriesId].
  bool _stillAwaits(String id, String seriesId, int number) {
    final current = _awaiting(id);
    return current != null &&
        awaitsBackfill(current) &&
        current.seriesId == seriesId &&
        current.number == number;
  }

  /// Ordre des recherches par numéro : ceux qui attendaient Google en
  /// dernier, puis les plus anciens ajouts, puis par numéro (une série
  /// ajoutée se complète dans l'ordre de ses tomes).
  int _backfillOrder(Volume a, Volume b) {
    final waiting = (_waitingGoogle.contains(a.id) ? 1 : 0).compareTo(
      _waitingGoogle.contains(b.id) ? 1 : 0,
    );
    if (waiting != 0) return waiting;
    final byAdded = a.addedAt.compareTo(b.addedAt);
    return byAdded != 0 ? byAdded : (a.number ?? 0).compareTo(b.number ?? 0);
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

  /// Écrit [completion] : le tome, sa série neuve, et le retrait des tomes
  /// non scannés qu'il remplace ([replacedByScan]), dans un même lot.
  /// Refusée, la série neuve est oubliée : les scans suivants ne s'y rangent
  /// pas.
  Future<AsyncValue<void>> _save(String uid, _Completion completion) async {
    final repository = ref.read(bookshelfRepositoryProvider);
    final newSeries = completion.newSeries;
    final volume = completion.volume;
    final replacing = switch ((volume.seriesId, volume.number)) {
      (final seriesId?, final number?) => replacedByScan(
        [..._volumes(), ..._queued.values],
        seriesId: seriesId,
        number: number,
        scannedId: volume.id,
      ),
      _ => const <String>[],
    };
    _queued.removeWhere((id, _) => replacing.contains(id));
    final result = await AsyncValue.guard(
      () => repository.saveScannedVolume(
        uid,
        volume,
        withSeries: newSeries == null
            ? null
            : (series: newSeries, createdAt: ref.read(clockProvider)()),
        replacing: replacing,
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

  /// Écrit [write] pour le compte connecté. [startedBy] : le compte connecté
  /// quand l'action a commencé ; une écriture différée (« Annuler ») est
  /// abandonnée si le compte a changé entre-temps, comme la suppression d'un
  /// anniversaire : un tome a pour id son ISBN, l'autre compte pourrait en
  /// avoir un du même nom.
  Future<void> _write(
    Future<void> Function(BookshelfRepository repository, String uid) write, {
    String? startedBy,
  }) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || (startedBy != null && startedBy != uid)) return;
    final repository = ref.read(bookshelfRepositoryProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => write(repository, uid));
    if (ref.mounted) state = result;
  }
}

/// Un tome à écrire, et la série neuve qu'il ouvre.
typedef _Completion = ({Volume volume, Series? newSeries});

/// Les recherches par numéro qui restent à un appel de `completePending`,
/// toutes passes comprises.
class _Budget {
  _Budget(this.left);

  int left;
}

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
