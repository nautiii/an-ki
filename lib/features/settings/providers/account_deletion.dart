import 'dart:async';

import 'package:an_ki/core/providers/user_data_hooks.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Suppression du compte (ViewModel du dialogue des réglages) et issue :
/// `AsyncLoading` pendant l'opération, `AsyncError` portant l'échec
/// (`AuthFailure` de la confirmation ou de la suppression, erreur de
/// l'effacement), sinon `AsyncData`.
///
/// Orchestration entre features : elle vit dans `settings`, qui dépend
/// d'`auth` et d'`user` ; les données des modules passent par leurs
/// effaceurs ([userDataErasersProvider], fournis par `app/`). Tant qu'elle
/// tourne, l'app ne recrée pas le profil effacé (`AppInitializer`).
class AccountDeletion extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Confirme l'identité ([password] pour un compte e-mail), efface les
  /// données Firestore (celles de chaque module, actif ou non, puis le
  /// profil), puis supprime le compte d'authentification. L'identité vient d'abord :
  /// Firebase refuse de supprimer un compte connecté depuis longtemps, et
  /// rien ne doit être effacé d'un compte qui resterait. Renvoie `true` une
  /// fois le compte supprimé ; une annulation (sélecteur Google fermé) laisse
  /// `AsyncData`.
  Future<bool> deleteAccount({String? password}) async {
    if (state.isLoading) return false;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return false;
    final auth = ref.read(authControllerProvider.notifier);
    // En vie jusqu'au bout, même si le dialogue disparaît : libéré entre
    // l'effacement et la suppression, il laisserait un compte vidé.
    final keepAlive = ref.keepAlive();
    state = const AsyncLoading();
    try {
      if (!await auth.confirmIdentity(password: password)) {
        _publishAuthOutcome();
        return false;
      }
      try {
        await _eraseData(uid);
      } catch (error, stackTrace) {
        if (ref.mounted) state = AsyncError(error, stackTrace);
        return false;
      }
      if (!await auth.deleteAccount()) {
        _publishAuthOutcome();
        return false;
      }
      if (ref.mounted) state = const AsyncData(null);
      return true;
    } finally {
      keepAlive.close();
    }
  }

  /// Les données de chaque module, puis le profil. Un effaceur qui échoue
  /// arrête tout : le profil reste, et le compte avec lui.
  Future<void> _eraseData(String uid) async {
    final erasers = ref.read(userDataErasersProvider);
    final users = ref.read(userRepositoryProvider);
    for (final erase in erasers) {
      await erase(uid);
    }
    await users.deleteUser(uid);
  }

  /// Reprend l'issue publiée par `AuthController` : son échec, ou rien
  /// (annulation).
  void _publishAuthOutcome() {
    if (!ref.mounted) return;
    state = switch (ref.read(authControllerProvider)) {
      AsyncError(:final error, :final stackTrace) => AsyncError(
        error,
        stackTrace,
      ),
      _ => const AsyncData(null),
    };
  }
}

final accountDeletionProvider =
    AsyncNotifierProvider.autoDispose<AccountDeletion, void>(
      AccountDeletion.new,
    );
