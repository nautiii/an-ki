import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_groups.dart';
import 'package:an_ki/features/birthday/providers/category_editor.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Retire [group] avec « Annuler » (Gmail), comme un anniversaire supprimé :
/// le groupe disparaît tout de suite de l'app (page, puces, filtres),
/// l'écriture ne part qu'à la fermeture de la snackbar sans annulation. Un
/// groupe privé ([kind] `own`) est supprimé, un groupe partagé quitte le
/// profil ; ses anniversaires le perdent. Un échec le fait réapparaître ;
/// l'accueil l'annonce.
void removeGroupWithUndo(
  BuildContext context,
  BirthdayCategory group,
  GroupKind kind,
) {
  // Tout est lu maintenant : la feuille qui retire est refermée, la page
  // peut l'être quand la snackbar se ferme.
  final container = ProviderScope.containerOf(context, listen: false);
  final pending = container.read(pendingGroupRemovalsProvider.notifier);
  final l10n = context.l10n;
  final name = group.localizedName(context);
  final accessible = MediaQuery.accessibleNavigationOf(context);

  unawaited(HapticFeedback.mediumImpact());
  pending.hide(group.id);
  final snackBar = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  final closed = snackBar
      .showSnackBar(
        SnackBar(
          content: Text(
            kind == GroupKind.own
                ? l10n.groupDeleted(name)
                : l10n.groupLeft(name),
          ),
          // Depuis Flutter 3.44, une snackbar avec action reste sinon ouverte.
          persist: false,
          duration: accessible ? undoDelay * 2 : undoDelay,
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => pending.restore(group.id),
          ),
        ),
      )
      .closed;

  unawaited(
    closed.then((reason) async {
      if (reason == SnackBarClosedReason.action) return;
      // Masqué jusqu'à la fin de l'écriture : les flux Firestore le retirent
      // d'eux-mêmes, un échec le rend visible à nouveau.
      await container
          .read(categoryEditorProvider.notifier)
          .remove(group.id, kind);
      pending.restore(group.id);
    }),
  );
}
