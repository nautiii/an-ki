import 'dart:async';

import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/domain/isbn.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/domain/volume_backfill.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ce que devient un code lu (caméra) ou saisi pendant une rafale.
enum ScanOutcome {
  /// Un nouveau tome, écrit sur l'étagère et empilé dans la rafale.
  added,

  /// Un ISBN que l'étagère a déjà : rien n'est écrit.
  alreadyOwned,

  /// La caméra relit un code déjà traité dans cette rafale : ignoré.
  repeated,

  /// Pas un ISBN valable (clé de contrôle fausse, code d'un produit).
  invalid,
}

/// Où en est un tome de la rafale, d'après l'étagère.
enum BurstRowStatus {
  /// Écrit, infos pas encore trouvées (hors ligne, ou recherche en cours).
  pending,

  /// Rangé dans une série, avec son numéro.
  classified,

  /// Trouvé mais sans série sûre : « à classer ».
  unclassified,

  /// Aucun catalogue ne le connaît : à classer à la main.
  notFound,
}

/// Une ligne de la rafale : un tome, et ce qu'on en sait.
class const BurstRow({
  required final String isbn,
  required final BurstRowStatus status,

  /// Sa série ([BurstRowStatus.classified]) : id, nom et image.
  final String? seriesId,
  final String? seriesName,
  final String? coverUrl,
  final int? number,

  /// Titre trouvé (vide tant qu'il est en attente).
  final String title = '',

  /// Numéros d'avant que sa série n'a pas ([missingBefore]) : « J'ai aussi
  /// les tomes 1 à 107 ». Vide pour un tome à classer.
  final List<int> missingPrevious = const [],
}) {
  @override
  bool operator ==(Object other) =>
      other is BurstRow &&
      other.isbn == isbn &&
      other.status == status &&
      other.seriesId == seriesId &&
      other.seriesName == seriesName &&
      other.coverUrl == coverUrl &&
      other.number == number &&
      other.title == title &&
      listEquals(other.missingPrevious, missingPrevious);

  @override
  int get hashCode => Object.hash(
    isbn,
    status,
    seriesId,
    seriesName,
    coverUrl,
    number,
    title,
    Object.hashAll(missingPrevious),
  );
}

/// Le résultat d'un code : son sort, et la ligne du tome concerné (l'ajouté,
/// ou celui déjà possédé, pour « Déjà dans votre collection · One Piece
/// 108 »).
typedef ScanResult = ({ScanOutcome outcome, BurstRow? row});

/// La rafale de la page `/books/scan` : les ISBN ajoutés pendant cette
/// ouverture, du plus récent au plus ancien. Vit le temps de la page
/// (autoDispose) et repart de zéro à chaque session.
///
/// Garde l'éditeur et l'étagère en vie tant que la page est ouverte : les
/// ajouts se complètent même si l'onglet n'est pas monté dessous.
class BurstScan extends Notifier<List<String>> {
  /// Codes déjà traités par cette rafale : la caméra relit le même code tant
  /// qu'il reste devant elle.
  final _seen = <String>{};

  /// Ajouts déjà écrits dans les tomes : s'ils en disparaissent (retirés
  /// depuis leur feuille, « Annuler » passé), leur ligne part aussi.
  final _shown = <String>{};

  @override
  List<String> build() {
    ref.watch(currentUidProvider);
    _seen.clear();
    _shown.clear();
    ref
      ..listen(shelfEditorProvider, (_, _) {})
      ..listen(shelfProvider, (_, _) {})
      // Le flux brut : un tome masqué le temps d'« Annuler » n'est pas parti.
      ..listen(bookVolumesProvider, (_, next) => _dropRemoved(next.value));
    return const [];
  }

  /// Traite le code [code]. [typed] : saisi à la main ; un ISBN déjà traité
  /// dans la rafale répond alors « déjà dans votre collection » au lieu de
  /// rien, puisque l'utilisateur l'a demandé.
  ScanResult scan(String code, {bool typed = false}) {
    final isbn = normalizeIsbn(code);
    if (isbn == null) return (outcome: ScanOutcome.invalid, row: null);
    if (!typed && _seen.contains(isbn)) {
      return (outcome: ScanOutcome.repeated, row: null);
    }
    final shelfState = ref.read(shelfProvider);
    // Étagère en cours de lecture (un instant à l'ouverture) : rien n'est
    // sûr, le code est ignoré sans être retenu ; la caméra le relira, une
    // saisie se refait. Illisible (règles, panne), on écrit quand même :
    // l'échec s'annonce comme toute écriture.
    if (!shelfState.hasValue && !shelfState.hasError) {
      return (outcome: ScanOutcome.repeated, row: null);
    }
    // Tome retiré, ou de sa série supprimée, dont « Annuler » court encore :
    // l'étagère le cache mais il existe. La caméra est ignorée sans retenir
    // le code ; une saisie dit qu'il est déjà là.
    if (_awaitingRemoval(isbn)) {
      return typed
          ? (outcome: ScanOutcome.alreadyOwned, row: burstRowOf(isbn, null))
          : (outcome: ScanOutcome.repeated, row: null);
    }
    final shelf = shelfState.value;
    _seen.add(isbn);
    if ((shelf != null && _volumeOf(shelf, isbn) != null) ||
        state.contains(isbn)) {
      return (outcome: ScanOutcome.alreadyOwned, row: burstRowOf(isbn, shelf));
    }
    state = [isbn, ...state];
    // Écrit aussitôt en attente, puis complété : l'éditeur annonce un échec.
    unawaited(ref.read(shelfEditorProvider.notifier).addScanned(isbn));
    return (outcome: ScanOutcome.added, row: burstRowOf(isbn, shelf));
  }

  bool _awaitingRemoval(String isbn) {
    if (ref.read(pendingVolumeRemovalsProvider).contains(isbn)) return true;
    final volumes = ref.read(bookVolumesProvider).value ?? const <Volume>[];
    final seriesId = volumes.where((v) => v.id == isbn).firstOrNull?.seriesId;
    return seriesId != null &&
        ref.read(pendingSeriesRemovalsProvider).contains(seriesId);
  }

  void _dropRemoved(List<Volume>? volumes) {
    if (volumes == null) return;
    final ids = {for (final volume in volumes) volume.id};
    final removed = <String>{};
    for (final isbn in state) {
      if (ids.contains(isbn)) {
        _shown.add(isbn);
      } else if (_shown.contains(isbn)) {
        removed.add(isbn);
      }
    }
    if (removed.isEmpty) return;
    // Retiré : il peut être rescanné.
    _seen.removeAll(removed);
    _shown.removeAll(removed);
    state = [
      for (final isbn in state)
        if (!removed.contains(isbn)) isbn,
    ];
  }
}

final burstScanProvider = NotifierProvider.autoDispose<BurstScan, List<String>>(
  BurstScan.new,
);

/// Les lignes de la rafale, du plus récent au plus ancien, suivant l'étagère
/// (un tome complété ou classé change de ligne aussitôt) ; un tome retiré
/// disparaît le temps d'« Annuler » et revient s'il est rétabli.
final burstRowsProvider = Provider.autoDispose<List<BurstRow>>((ref) {
  final shelf = ref.watch(shelfProvider).value;
  final hidden = ref.watch(pendingVolumeRemovalsProvider);
  // Une série supprimée ou fusionnée depuis sa page attend « Annuler » : ses
  // tomes ne sont pas « en attente », ils partent avec elle.
  final hiddenSeries = ref.watch(pendingSeriesRemovalsProvider);
  final leaving = {
    for (final volume
        in ref.watch(bookVolumesProvider).value ?? const <Volume>[])
      if (hiddenSeries.contains(volume.seriesId)) volume.id,
  };
  return [
    for (final isbn in ref.watch(burstScanProvider))
      if (!hidden.contains(isbn) && !leaving.contains(isbn))
        burstRowOf(isbn, shelf),
  ];
});

/// La ligne du tome [isbn] d'après [shelf] ; en attente tant que l'étagère ne
/// le montre pas encore. Un tome scanné a cet ISBN pour id ; à défaut, la
/// ligne est celle du tome qui porte cet ISBN (trouvé par « les tomes
/// précédents »).
BurstRow burstRowOf(String isbn, Shelf? shelf) {
  if (shelf == null) {
    return BurstRow(isbn: isbn, status: BurstRowStatus.pending);
  }
  for (final byIsbnField in const [false, true]) {
    bool matches(Volume volume) =>
        byIsbnField ? volume.isbn == isbn : volume.id == isbn;
    for (final entry in shelf.entries) {
      for (final volume in entry.volumes) {
        if (matches(volume)) {
          return BurstRow(
            isbn: isbn,
            status: BurstRowStatus.classified,
            seriesId: entry.series.id,
            seriesName: entry.series.name,
            coverUrl: entry.coverUrl,
            number: volume.number,
            title: volume.title,
            missingPrevious: missingBefore(entry, volume.number!),
          );
        }
      }
    }
    if (shelf.unclassified.where(matches).firstOrNull case final volume?) {
      return _unclassifiedRow(isbn, volume);
    }
  }
  return _unclassifiedRow(isbn, null);
}

BurstRow _unclassifiedRow(String isbn, Volume? volume) => BurstRow(
  isbn: isbn,
  status: switch (volume?.lookup) {
    null || LookupState.pending => BurstRowStatus.pending,
    LookupState.notFound => BurstRowStatus.notFound,
    LookupState.found => BurstRowStatus.unclassified,
  },
  title: volume?.title ?? '',
);

/// Le tome [isbn] de [shelf] : celui qui l'a pour id (scanné), sinon celui
/// qui porte cet ISBN (trouvé par « les tomes précédents »).
Volume? _volumeOf(Shelf shelf, String isbn) {
  final volumes = [
    for (final entry in shelf.entries) ...entry.volumes,
    ...shelf.unclassified,
  ];
  return volumes.where((v) => v.id == isbn).firstOrNull ??
      volumes.where((v) => v.isbn == isbn).firstOrNull;
}

/// Un groupe du ticket de la rafale : les tomes d'une même série, ou un tome
/// seul pas encore rangé.
class const BurstGroup({
  /// Du plus récent au plus ancien, comme la rafale.
  required final List<BurstRow> rows,
}) {
  /// Vrai pour les tomes rangés d'une série.
  bool get isSeries => rows.first.status == BurstRowStatus.classified;

  /// Numéros des tomes, croissants (un groupe de série).
  List<int> get numbers => [for (final row in rows) ?row.number]..sort();

  @override
  bool operator ==(Object other) =>
      other is BurstGroup && listEquals(other.rows, rows);

  @override
  int get hashCode => Object.hashAll(rows);
}

/// Les lignes [rows] de la rafale en groupes : les tomes rangés par série, à
/// la place du plus récent de la série ; les autres un par un, à leur place.
List<BurstGroup> burstGroupsOf(List<BurstRow> rows) {
  final bySeries = <String, List<BurstRow>>{};
  final order = <Object>[];
  for (final row in rows) {
    final seriesId = row.seriesId;
    if (row.status == BurstRowStatus.classified && seriesId != null) {
      final group = bySeries[seriesId];
      if (group == null) {
        bySeries[seriesId] = [row];
        order.add(seriesId);
      } else {
        group.add(row);
      }
    } else {
      order.add(row);
    }
  }
  return [
    for (final key in order)
      BurstGroup(rows: key is String ? bySeries[key]! : [key as BurstRow]),
  ];
}
