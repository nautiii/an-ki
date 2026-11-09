import 'package:an_ki/core/providers/user_data_hooks.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/shelf_takeover.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Effaceur des données de Livres (suppression du compte) : tomes, séries,
/// puis anciens livres. Branché par `app/` dans le registre des modules.
final shelfDataEraserProvider = Provider<UserDataEraser>(
  (ref) => ref.watch(bookshelfRepositoryProvider).deleteAllUserData,
);

/// Reprise de l'étagère d'un invité par un compte Google existant : l'invité
/// la marque et la lit (sur le serveur) avant la connexion ; le compte cible,
/// une fois ouvert, lit la sienne, planifie ([planShelfTakeOver]) puis copie
/// et efface. Branchée par `app/` dans le registre des modules.
final shelfGuestTransferProvider = Provider<GuestDataTransfer>((ref) {
  final repository = ref.watch(bookshelfRepositoryProvider);
  return (String guestUid, String email) async {
    final marked = await repository.markForTransfer(guestUid, email);
    return (String targetUid) async {
      if (marked.isEmpty) return;
      final target = await repository.fetchShelf(targetUid);
      await repository.takeOver(
        targetUid,
        planShelfTakeOver(
          marked,
          targetSeries: target.series,
          targetVolumes: target.volumes,
        ),
      );
    };
  };
});
