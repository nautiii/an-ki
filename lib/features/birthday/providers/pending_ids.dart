import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ids masqués pendant le délai « Annuler » d'une suppression, puis jusqu'à
/// la fin de l'écriture. Vide à chaque changement d'utilisateur.
class PendingIds extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(currentUidProvider);
    return const {};
  }

  void hide(String id) => state = {...state, id};

  void restore(String id) => state = {
    for (final pending in state)
      if (pending != id) pending,
  };
}
