import 'dart:async';

import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/repositories/birthday_repository.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Effacement des données Firestore du compte (anniversaires, puis profil),
/// que l'écran fait suivre de la suppression du compte d'authentification.
///
/// Opération attendue : le compte n'est supprimé qu'une fois ses données
/// effacées. Relève de l'orchestration entre features : elle rejoindra la
/// feature `settings` (migration M4).
class AccountDeletion extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Efface les données de l'utilisateur courant ; relance l'erreur pour que
  /// l'écran n'aille pas plus loin.
  Future<void> eraseData() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final birthdays = ref.read(birthdayRepositoryProvider);
    final users = ref.read(userRepositoryProvider);
    state = const AsyncLoading();
    try {
      await birthdays.deleteAllUserBirthdays(uid);
      await users.deleteUser(uid);
      if (ref.mounted) state = const AsyncData(null);
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final accountDeletionProvider =
    AsyncNotifierProvider.autoDispose<AccountDeletion, void>(
      AccountDeletion.new,
    );
