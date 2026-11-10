import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// Ids masqués pendant le délai « Annuler » d'une suppression, puis jusqu'à
/// la fin de l'écriture. Vide à chaque changement du provider reçu : la session
/// (`currentUidProvider`), que `core` ne connaît pas et que chaque feature
/// passe en déclarant son provider.
class PendingIds extends Notifier<Set<String>> {
  PendingIds(this._resetOn);

  final ProviderListenable<Object?> _resetOn;

  @override
  Set<String> build() {
    ref.watch(_resetOn);
    return const {};
  }

  void hide(String id) => state = {...state, id};

  void restore(String id) => state = {
    for (final pending in state)
      if (pending != id) pending,
  };
}
