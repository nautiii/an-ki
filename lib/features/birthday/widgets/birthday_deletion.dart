import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Délai pour annuler une suppression ; doublé avec TalkBack, le temps
/// d'atteindre l'action.
const Duration undoDelay = Duration(seconds: 5);

/// Supprime [birthday] avec « Annuler » (Gmail) : la personne disparaît tout
/// de suite de l'app, l'effacement ne part qu'à la fermeture de la snackbar
/// sans annulation. Un échec la fait réapparaître ; l'accueil l'annonce.
void deleteWithUndo(BuildContext context, Birthday birthday) {
  // Tout est lu maintenant : l'élément qui supprime (ligne glissée, feuille
  // refermée) n'existe sans doute plus quand la snackbar se ferme.
  final container = ProviderScope.containerOf(context, listen: false);
  final pending = container.read(pendingDeletionsProvider.notifier);
  final l10n = context.l10n;
  final accessible = MediaQuery.accessibleNavigationOf(context);

  unawaited(HapticFeedback.mediumImpact());
  pending.hide(birthday.id);
  final snackBar = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  final closed = snackBar
      .showSnackBar(
        SnackBar(
          content: Text(l10n.birthdayDeleted(birthday.fullName)),
          // Depuis Flutter 3.44, une snackbar avec action reste sinon ouverte.
          persist: false,
          duration: accessible ? undoDelay * 2 : undoDelay,
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => pending.restore(birthday.id),
          ),
        ),
      )
      .closed;

  unawaited(
    closed.then((reason) async {
      if (reason == SnackBarClosedReason.action) return;
      // Masquée jusqu'à la fin de l'écriture : le flux Firestore la retire
      // de lui-même, un échec la rend visible à nouveau.
      await container.read(birthdayEditorProvider.notifier).delete(birthday.id);
      pending.restore(birthday.id);
    }),
  );
}
