import 'dart:async';

import 'package:an_ki/core/extensions/firestore_extensions.dart';
import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/features/books/domain/legacy_import.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/shelf_takeover.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bookshelfRepositoryProvider = Provider<BookshelfRepository>(
  (ref) => BookshelfRepository(firestore: ref.watch(firestoreProvider)),
);

/// Une étagère lue d'un coup : séries et tomes d'un compte.
typedef ShelfContents = ({List<Series> series, List<Volume> volumes});

/// L'étagère d'un utilisateur dans Firestore : ses séries
/// (`user/{uid}/bookSeries`) et ses tomes (`user/{uid}/bookVolumes`, id =
/// ISBN pour un tome scanné), plus l'ancienne liste `books` (documents portant
/// leur `uid`), lue pour l'import, l'effacement et la reprise d'un invité.
///
/// Convertit documents ↔ domaine et traduit les erreurs de Firestore en
/// [ShelfFailure], sauf celles des méthodes de compte ([deleteAllUserData],
/// [markForTransfer], [takeOver]) : leurs appelants (`settings`, par les
/// crochets des modules) lisent la `FirebaseException`, comme pour les autres
/// modules (`unavailable` : hors ligne). Ni logique métier, ni texte d'UI, ni
/// état : les plans (import, reprise) viennent du domaine. Les écritures se
/// résolvent à l'accusé du serveur : l'UI ne les attend pas.
class BookshelfRepository {
  BookshelfRepository({required this._firestore});

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _series(String uid) =>
      _firestore.collection('user').doc(uid).collection('bookSeries');

  CollectionReference<Map<String, dynamic>> _volumes(String uid) =>
      _firestore.collection('user').doc(uid).collection('bookVolumes');

  CollectionReference<Map<String, dynamic>> get _legacyBooks =>
      _firestore.collection('books');

  // --- Lecture ---

  /// Toutes les séries de [uid], en temps réel ; l'ordre est celui de
  /// Firestore, à l'écran de trier.
  Stream<List<Series>> watchSeries(String uid) =>
      _series(uid)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(_seriesFromDoc).toList())
          .transform(_translateErrors());

  /// Tous les tomes de [uid], en temps réel.
  Stream<List<Volume>> watchVolumes(String uid) =>
      _volumes(uid)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(_volumeFromDoc).toList())
          .transform(_translateErrors());

  /// Séries et tomes de [uid], lus sur le serveur (import, reprise) : hors
  /// ligne, [ShelfFailure.offline].
  Future<ShelfContents> fetchShelf(String uid) => _guard(() async {
    final series = await _series(uid).get(_server);
    final volumes = await _volumes(uid).get(_server);
    return (
      series: series.docs.map(_seriesFromDoc).toList(),
      volumes: volumes.docs.map(_volumeFromDoc).toList(),
    );
  });

  /// Anciens livres de [uid] (`books`) pas encore importés, lus sur le
  /// serveur.
  Future<List<LegacyBook>> fetchLegacyBooks(String uid) => _guard(() async {
    final snapshot = await _legacyBooks
        .where('uid', isEqualTo: uid)
        .get(_server);
    return [
      for (final doc in snapshot.docs)
        if (doc.data()['importedAt'] == null) _legacyBookFromDoc(doc),
    ];
  });

  // --- Tomes ---

  /// Écrit le tome scanné [volume] (id = ISBN), par fusion : rescanner, même
  /// hors ligne ou depuis deux appareils, réécrit le même document. Seuls les
  /// champs connus sont écrits : un tome en attente n'efface pas un titre.
  /// [withSeries] : la série neuve qu'il ouvre, créée dans le même lot (jamais
  /// un tome vers une série refusée).
  Future<void> saveScannedVolume(
    String uid,
    Volume volume, {
    ({Series series, DateTime createdAt})? withSeries,
  }) => _guard(() {
    final volumeDoc = _volumes(uid).doc(volume.id);
    if (withSeries == null) {
      return volumeDoc.set(_volumeToMap(volume), SetOptions(merge: true));
    }
    final (:series, :createdAt) = withSeries;
    return _firestore.writeInBatches(<void Function(WriteBatch)>[
      (batch) => batch.set(
        _series(uid).doc(series.id),
        _seriesToMap(series, createdAt: createdAt),
      ),
      (batch) =>
          batch.set(volumeDoc, _volumeToMap(volume), SetOptions(merge: true)),
    ], (batch, write) => write(batch));
  });

  /// Range le tome [volumeId] dans [seriesId] au numéro [number] ; null efface
  /// le champ (sans série : « à classer »).
  Future<void> classifyVolume(
    String uid,
    String volumeId, {
    required String? seriesId,
    required int? number,
  }) => _guard(
    () => _volumes(uid).doc(volumeId).update({
      'seriesId': seriesId ?? FieldValue.delete(),
      'number': number ?? FieldValue.delete(),
    }),
  );

  Future<void> deleteVolume(String uid, String volumeId) =>
      _guard(() => _volumes(uid).doc(volumeId).delete());

  // --- Séries ---

  /// Id d'une nouvelle série de [uid], tiré côté client : utilisable hors
  /// ligne avant même l'écriture.
  String newSeriesId(String uid) => _series(uid).doc().id;

  /// Crée [series] (id tiré par [newSeriesId]), datée de [createdAt].
  Future<void> createSeries(
    String uid,
    Series series, {
    required DateTime createdAt,
  }) => _guard(
    () =>
        _series(uid)
            .doc(series.id)
            .set(_seriesToMap(series, createdAt: createdAt)),
  );

  /// Renomme la série [seriesId] en [name] et ajoute [key] à ses clés : les
  /// anciennes restent, un scan sous l'ancien nom la retrouve.
  Future<void> renameSeries(
    String uid,
    String seriesId, {
    required String name,
    required String key,
  }) => _guard(
    () => _series(uid).doc(seriesId).update({
      'name': name,
      'keys': FieldValue.arrayUnion([key]),
    }),
  );

  /// Fusionne la série [sourceId] dans [targetId] : ses tomes passent dans la
  /// cible, [keys] (celles de la source) s'ajoutent aux siennes, puis la
  /// source est supprimée, dans un même lot (au-delà de 500 opérations,
  /// plusieurs). Les tomes sont lus du cache hors ligne, du serveur sinon.
  Future<void> mergeSeries(
    String uid, {
    required String sourceId,
    required String targetId,
    required List<String> keys,
  }) => _guard(() async {
    if (sourceId == targetId) return;
    final volumes = await _volumes(uid)
        .where('seriesId', isEqualTo: sourceId)
        .get();
    final operations = <void Function(WriteBatch)>[
      for (final doc in volumes.docs)
        (batch) => batch.update(doc.reference, {'seriesId': targetId}),
      if (keys.isNotEmpty)
        (batch) => batch.update(_series(uid).doc(targetId), {
          'keys': FieldValue.arrayUnion(keys),
        }),
      (batch) => batch.delete(_series(uid).doc(sourceId)),
    ];
    await _firestore.writeInBatches(operations, (batch, write) => write(batch));
  });

  /// Marque la série [seriesId] terminée ([complete]) ou non.
  Future<void> setSeriesComplete(
    String uid,
    String seriesId, {
    required bool complete,
  }) => _guard(() => _series(uid).doc(seriesId).update({'complete': complete}));

  /// Ce qu'on sait du prochain tome de [seriesId] ; null l'efface.
  Future<void> setNextVolume(
    String uid,
    String seriesId,
    NextVolumeInfo? next,
  ) => _guard(
    () => _series(uid).doc(seriesId).update({
      'next': next == null ? FieldValue.delete() : _nextToMap(next),
    }),
  );

  // --- Import des anciens livres ---

  /// Écrit le plan d'import [plan] : chaque entrée (sa série neuve, son tome,
  /// la marque `importedAt` de ses anciens documents) tient dans un même lot,
  /// si bien qu'un import coupé reprend là où il s'est arrêté sans réécrire un
  /// tome retiré depuis.
  Future<void> applyLegacyImport(
    String uid,
    LegacyImportPlan plan, {
    required DateTime importedAt,
  }) => _guard(() async {
    // Une série neuve part dans le lot de tous ses tomes : jamais un tome
    // écrit vers une série dont le lot aurait échoué.
    final newSeriesIds = {
      for (final entry in plan.entries) ?entry.newSeries?.id,
    };
    final groups = <String, List<void Function(WriteBatch)>>{};
    for (final (index, entry) in plan.entries.indexed) {
      final seriesId = entry.volume?.seriesId;
      final group = groups.putIfAbsent(
        newSeriesIds.contains(seriesId) ? 'series:$seriesId' : 'entry:$index',
        () => [],
      );
      if (entry.newSeries case final series?) {
        group.add(
          (batch) => batch.set(
            _series(uid).doc(series.id),
            _seriesToMap(series, createdAt: importedAt),
          ),
        );
      }
      if (entry.volume case final volume?) {
        group.add(
          (batch) => batch.set(
            _volumes(uid).doc(volume.id),
            _volumeToMap(volume),
            SetOptions(merge: true),
          ),
        );
      }
      for (final id in entry.legacyBookIds) {
        group.add(
          (batch) => batch.update(_legacyBooks.doc(id), {
            'importedAt': Timestamp.fromDate(importedAt),
          }),
        );
      }
    }
    await Future.wait([
      for (final chunk in chunkGroups([...groups.values]))
        _firestore.writeInBatches(chunk, (batch, write) => write(batch)),
    ]);
  });

  // --- Compte ---

  /// Efface l'étagère de [uid] (suppression du compte) : ses tomes, ses
  /// séries, puis ses anciens livres. Lu sur le serveur : hors ligne, rien ne
  /// commence (`FirebaseException` `unavailable`).
  Future<void> deleteAllUserData(String uid) async {
    for (final query in <Query<Map<String, dynamic>>>[
      _volumes(uid),
      _series(uid),
      _legacyBooks.where('uid', isEqualTo: uid),
    ]) {
      final snapshot = await query.get(_server);
      await _firestore.writeInBatches(
        snapshot.docs,
        (batch, doc) => batch.delete(doc.reference),
      );
    }
  }

  /// Marque l'étagère de [uid], un invité, pour le compte Google [email] qui
  /// va la reprendre ([takeOver]), et renvoie ce qu'elle contient : ce compte
  /// ne pourra pas la lire. Lu sur le serveur ; le Future attend l'accusé.
  Future<MarkedShelf> markForTransfer(String uid, String email) async {
    final series = await _series(uid).get(_server);
    final volumes = await _volumes(uid).get(_server);
    final legacy = await _legacyBooks.where('uid', isEqualTo: uid).get(_server);
    await _firestore.writeInBatches([
      ...series.docs,
      ...volumes.docs,
      ...legacy.docs,
    ], (batch, doc) => batch.update(doc.reference, {'transferTo': email}));
    return MarkedShelf(
      guestUid: uid,
      series: series.docs.map(_seriesFromDoc).toList(),
      volumes: volumes.docs.map(_volumeFromDoc).toList(),
      legacyBookIds: [for (final doc in legacy.docs) doc.id],
    );
  }

  /// Reprend pour [targetUid] l'étagère d'un invité selon [plan] : copie sous
  /// son chemin (séries, clés, tomes), puis, la copie acquise, supprime les
  /// documents marqués de l'invité et reprend ses anciens livres par leur
  /// `uid`, sans marque.
  Future<void> takeOver(String targetUid, ShelfTakeOverPlan plan) async {
    await _firestore.writeInBatches(<void Function(WriteBatch)>[
      for (final series in plan.seriesToCopy)
        (batch) =>
            batch.set(_series(targetUid).doc(series.id), _seriesToMap(series)),
      for (final MapEntry(key: id, value: keys) in plan.keysToAdd.entries)
        (batch) => batch.update(_series(targetUid).doc(id), {
          'keys': FieldValue.arrayUnion(keys),
        }),
      for (final volume in plan.volumesToCopy)
        (batch) =>
            batch.set(_volumes(targetUid).doc(volume.id), _volumeToMap(volume)),
    ], (batch, write) => write(batch));
    await _firestore.writeInBatches(<void Function(WriteBatch)>[
      for (final id in plan.guestVolumeIds)
        (batch) => batch.delete(_volumes(plan.guestUid).doc(id)),
      for (final id in plan.guestSeriesIds)
        (batch) => batch.delete(_series(plan.guestUid).doc(id)),
      for (final id in plan.legacyBookIds)
        (batch) => batch.update(_legacyBooks.doc(id), {
          'uid': targetUid,
          'transferTo': FieldValue.delete(),
        }),
    ], (batch, write) => write(batch));
  }
}

const _server = GetOptions(source: Source.server);

/// Regroupe [groups] en paquets d'au plus [BatchedWrites.batchLimit]
/// opérations sans couper un groupe (sauf un groupe plus grand qu'un lot) :
/// chacun part dans un seul lot, donc s'écrit en entier ou pas du tout.
@visibleForTesting
List<List<T>> chunkGroups<T>(List<List<T>> groups) {
  final chunks = <List<T>>[];
  var current = <T>[];
  for (final group in groups) {
    if (current.isNotEmpty &&
        current.length + group.length > BatchedWrites.batchLimit) {
      chunks.add(current);
      current = [];
    }
    current.addAll(group);
  }
  if (current.isNotEmpty) chunks.add(current);
  return chunks;
}

/// Exécute [operation] en traduisant les erreurs de Firestore en
/// [ShelfFailure], pile d'appels gardée.
Future<T> _guard<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on FirebaseException catch (error, stack) {
    Error.throwWithStackTrace(_failureOf(error), stack);
  }
}

StreamTransformer<T, T> _translateErrors<T>() => StreamTransformer.fromHandlers(
  handleError: (error, stack, sink) => sink.addError(
    error is FirebaseException ? _failureOf(error) : error,
    stack,
  ),
);

ShelfFailure _failureOf(FirebaseException error) => switch (error.code) {
  'unavailable' => ShelfFailure.offline,
  'permission-denied' || 'unauthenticated' => ShelfFailure.denied,
  _ => ShelfFailure.failed,
};

// --- Conversions, privées au data layer. Lecture tolérante : un champ
// absent ou d'un autre type prend sa valeur par défaut. ---

Series _seriesFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return Series(
    id: doc.id,
    name: _string(data['name']) ?? '',
    keys: _strings(data['keys']),
    complete: data['complete'] == true,
    next: _nextFromMap(data['next']),
  );
}

Map<String, Object> _seriesToMap(Series series, {DateTime? createdAt}) => {
  'name': series.name,
  'keys': series.keys,
  if (series.complete) 'complete': true,
  if (series.next case final next?) 'next': _nextToMap(next),
  if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt),
};

/// La carte `next` ; null quand elle manque ou qu'un champ requis est
/// illisible (statut ou source inconnus : version plus récente de l'app).
NextVolumeInfo? _nextFromMap(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final number = _int(raw['number']);
  final status = _enumByName(ReleaseStatus.values, raw['status']);
  final source = _enumByName(ReleaseSource.values, raw['source']);
  final checkedAt = raw['checkedAt'];
  if (number == null ||
      status == null ||
      source == null ||
      checkedAt is! Timestamp) {
    return null;
  }
  final date = _string(raw['date']);
  return NextVolumeInfo(
    number: number,
    status: status,
    date: date == null ? null : ReleaseDate.tryParse(date),
    source: source,
    checkedAt: checkedAt.toDate(),
  );
}

/// La date en chaîne ISO avec sa précision (`2026-12-03`, `2026-12`), jamais
/// en `Timestamp` : pas de décalage de fuseau.
Map<String, Object> _nextToMap(NextVolumeInfo next) => {
  'number': next.number,
  'status': next.status.name,
  if (next.date case final date?) 'date': date.iso,
  'source': next.source.name,
  'checkedAt': Timestamp.fromDate(next.checkedAt),
};

Volume _volumeFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final title = _string(data['title']) ?? '';
  final addedAt = data['addedAt'];
  return Volume(
    id: doc.id,
    seriesId: _string(data['seriesId']),
    number: _int(data['number']),
    isbn: _string(data['isbn']),
    title: title,
    authors: _strings(data['authors']),
    imageUrl: _string(data['imageUrl']),
    publisher: _string(data['publisher']),
    publishedDate: _string(data['publishedDate']),
    // Sans état connu : trouvé s'il a un titre, sinon à chercher.
    lookup:
        _enumByName(LookupState.values, data['lookup']) ??
        (title.isEmpty ? LookupState.pending : LookupState.found),
    // Sans date : le plus ancien de l'étagère.
    addedAt: addedAt is Timestamp
        ? addedAt.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Les champs connus de [volume] : un titre vide, une liste d'auteurs vide, un
/// optionnel null ou l'état `pending` ne sont pas écrits (une fusion ne les
/// efface pas ; un tome sans titre ni état se lit en attente).
Map<String, Object> _volumeToMap(Volume volume) => {
  'seriesId': ?volume.seriesId,
  'number': ?volume.number,
  'isbn': ?volume.isbn,
  if (volume.title.isNotEmpty) 'title': volume.title,
  if (volume.authors.isNotEmpty) 'authors': volume.authors,
  'imageUrl': ?volume.imageUrl,
  'publisher': ?volume.publisher,
  'publishedDate': ?volume.publishedDate,
  if (volume.lookup != LookupState.pending) 'lookup': volume.lookup.name,
  'addedAt': Timestamp.fromDate(volume.addedAt),
};

LegacyBook _legacyBookFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final scannedAt = data['scannedAt'];
  return LegacyBook(
    id: doc.id,
    title: _string(data['title']) ?? '',
    authors: _strings(data['authors']),
    isbn: _string(data['isbn']) ?? '',
    imageUrl: _string(data['imageUrl']),
    publishedDate: _string(data['publishedDate']),
    scannedAt: scannedAt is Timestamp ? scannedAt.toDate() : null,
  );
}

String? _string(Object? value) => value is String ? value : null;

List<String> _strings(Object? value) => [
  if (value is List<Object?>)
    for (final item in value)
      if (item is String) item,
];

/// Un entier, ou un nombre décimal sans partie fractionnaire.
int? _int(Object? value) => switch (value) {
  final int number => number,
  final double number
      when number.isFinite && number == number.roundToDouble() =>
    number.toInt(),
  _ => null,
};

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
