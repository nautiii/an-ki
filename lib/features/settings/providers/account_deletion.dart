import 'dart:async';

import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Suppression du compte (ViewModel du dialogue des réglages) et issue :
/// `AsyncLoading` pendant l'opération, `AsyncError` portant l'échec
/// (`AuthFailure` de la confirmation ou de la suppression, erreur de
/// l'effacement), sinon `AsyncData`.
///
/// Orchestration entre features : elle vit dans `settings`, qui dépend de
/// chacune d'elles. Tant qu'elle tourne, l'app ne recrée pas le profil
/// effacé (`AppInitializer`).
class AccountDeletion extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Confirme l'identité ([password] pour un compte e-mail), efface les
  /// données Firestore (anniversaires, livres, groupes privés, puis profil),
  /// puis supprime le compte d'authentification. L'identité vient d'abord :
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

  Future<void> _eraseData(String uid) async {
    final birthdays = ref.read(birthdayRepositoryProvider);
    final books = ref.read(bookRepositoryProvider);
    final categories = ref.read(categoryRepositoryProvider);
    final users = ref.read(userRepositoryProvider);
    await birthdays.deleteAllUserBirthdays(uid);
    await books.deleteAllUserBooks(uid);
    await categories.deleteAllUserCategories(uid);
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
