import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/pending_ids.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Délai pour annuler une correction de l'étagère ; doublé avec TalkBack, le
/// temps d'atteindre l'action.
const Duration shelfUndoDelay = Duration(seconds: 5);

/// Supprime la série de [entry] avec ses tomes, avec « Annuler » : elle
/// disparaît tout de suite, l'effacement part à la fermeture de la snackbar
/// sans annulation.
void deleteSeriesWithUndo(BuildContext context, ShelfEntry entry) {
  final series = entry.series;
  _hideThenWrite(
    context,
    pendingProvider: pendingSeriesRemovalsProvider,
    id: series.id,
    message: context.l10n.seriesDeleted(series.name, entry.volumes.length),
    write: (editor, uid) => editor.deleteSeries(series.id, uid: uid),
  );
}

/// Fusionne la série de [source] dans [target], avec « Annuler » : la source
/// disparaît tout de suite, ses tomes rejoignent la cible à la fermeture de
/// la snackbar.
void mergeSeriesWithUndo(
  BuildContext context, {
  required ShelfEntry source,
  required ShelfEntry target,
}) => _hideThenWrite(
  context,
  pendingProvider: pendingSeriesRemovalsProvider,
  id: source.series.id,
  message: context.l10n.seriesMerged(source.series.name, target.series.name),
  write: (editor, uid) => editor.mergeSeries(
    sourceId: source.series.id,
    targetId: target.series.id,
    uid: uid,
  ),
);

/// Retire [volume] de la collection, avec « Annuler ».
void removeVolumeWithUndo(
  BuildContext context,
  Volume volume, {
  required String title,
}) => _hideThenWrite(
  context,
  pendingProvider: pendingVolumeRemovalsProvider,
  id: volume.id,
  message: context.l10n.volumeRemoved(title),
  write: (editor, uid) => editor.removeVolume(volume.id, uid: uid),
);

/// Masque [id] ([pendingProvider]), propose « Annuler », puis écrit [write]
/// si personne n'a annulé. Tout est lu maintenant : la page qui agit (feuille
/// refermée, série quittée) n'existe sans doute plus à la fermeture de la
/// snackbar. L'id reste masqué jusqu'à la fin de l'écriture : le flux de
/// Firestore le retire de lui-même, un échec le rend visible à nouveau.
void _hideThenWrite(
  BuildContext context, {
  required NotifierProvider<PendingIds, Set<String>> pendingProvider,
  required String id,
  required String message,
  required Future<void> Function(ShelfEditor editor, String? uid) write,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  // Le compte de départ : un changement de compte pendant le délai abandonne
  // l'écriture (voir `ShelfEditor`).
  final uid = container.read(currentUidProvider);
  final pending = container.read(pendingProvider.notifier);
  // L'éditeur est libéré sans auditeur : on le garde en vie jusqu'à la fin.
  final keepAlive = container.listen(shelfEditorProvider, (_, _) {});
  final l10n = context.l10n;
  final accessible = MediaQuery.accessibleNavigationOf(context);

  unawaited(HapticFeedback.mediumImpact());
  pending.hide(id);
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  unawaited(
    messenger
        .showSnackBar(
          SnackBar(
            content: Text(message),
            // Depuis Flutter 3.44, une snackbar avec action reste sinon ouverte.
            persist: false,
            duration: accessible ? shelfUndoDelay * 2 : shelfUndoDelay,
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => pending.restore(id),
            ),
          ),
        )
        .closed
        .then((reason) async {
          try {
            if (reason == SnackBarClosedReason.action) return;
            await write(container.read(shelfEditorProvider.notifier), uid);
            pending.restore(id);
          } finally {
            keepAlive.close();
          }
        }),
  );
}
