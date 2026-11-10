import 'dart:async';

import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Vrai quand l'étagère n'est lue que du cache depuis [ShelfOffline.grace] :
/// hors ligne. Le délai évite un bandeau éclair à l'ouverture, le temps que
/// le serveur réponde. Faux hors session, ou quand le flux échoue (l'étagère
/// montre alors sa propre erreur).
class ShelfOffline extends Notifier<bool> {
  /// Temps passé sur le seul cache avant de se dire hors ligne.
  static const Duration grace = Duration(seconds: 3);

  @override
  bool build() {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return false;
    Timer? pending;
    final subscription = ref
        .watch(bookshelfRepositoryProvider)
        .watchFromCache(uid)
        .listen(
          (fromCache) {
            pending?.cancel();
            if (fromCache) {
              pending = Timer(grace, () => state = true);
            } else {
              state = false;
            }
          },
          onError: (Object _) {
            pending?.cancel();
            state = false;
          },
        );
    ref.onDispose(() {
      pending?.cancel();
      unawaited(subscription.cancel());
    });
    return false;
  }
}

final shelfOfflineProvider = NotifierProvider.autoDispose<ShelfOffline, bool>(
  ShelfOffline.new,
);
