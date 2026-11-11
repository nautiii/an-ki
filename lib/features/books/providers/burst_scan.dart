import 'dart:async';

import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/domain/isbn.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
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

  /// Nom de sa série ([BurstRowStatus.classified]).
  final String? seriesName,
  final int? number,

  /// Titre trouvé (vide tant qu'il est en attente).
  final String title = '',
}) {
  @override
  bool operator ==(Object other) =>
      other is BurstRow &&
      other.isbn == isbn &&
      other.status == status &&
      other.seriesName == seriesName &&
      other.number == number &&
      other.title == title;

  @override
  int get hashCode => Object.hash(isbn, status, seriesName, number, title);
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
  return [
    for (final isbn in ref.watch(burstScanProvider))
      if (!hidden.contains(isbn)) burstRowOf(isbn, shelf),
  ];
});

/// La ligne du tome [isbn] d'après [shelf] ; en attente tant que l'étagère ne
/// le montre pas encore.
BurstRow burstRowOf(String isbn, Shelf? shelf) {
  if (shelf == null) {
    return BurstRow(isbn: isbn, status: BurstRowStatus.pending);
  }
  for (final entry in shelf.entries) {
    for (final volume in entry.volumes) {
      if (volume.id == isbn) {
        return BurstRow(
          isbn: isbn,
          status: BurstRowStatus.classified,
          seriesName: entry.series.name,
          number: volume.number,
          title: volume.title,
        );
      }
    }
  }
  final volume = shelf.unclassified.where((v) => v.id == isbn).firstOrNull;
  return BurstRow(
    isbn: isbn,
    status: switch (volume?.lookup) {
      null || LookupState.pending => BurstRowStatus.pending,
      LookupState.notFound => BurstRowStatus.notFound,
      LookupState.found => BurstRowStatus.unclassified,
    },
    title: volume?.title ?? '',
  );
}

Volume? _volumeOf(Shelf shelf, String isbn) {
  for (final entry in shelf.entries) {
    for (final volume in entry.volumes) {
      if (volume.id == isbn) return volume;
    }
  }
  return shelf.unclassified.where((v) => v.id == isbn).firstOrNull;
}
