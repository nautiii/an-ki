import 'dart:async';

import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/guest_merge_plan.dart';
import 'package:an_ki/features/books/data/book_repository.dart';
import 'package:an_ki/features/settings/domain/guest_merge_failure.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ouverture, par un invité, du compte Google qu'AnKi connaît déjà, avec ses
/// anniversaires (B5.5) ; ViewModel de la carte de sauvegarde. Issue :
/// `AsyncLoading` pendant l'opération, `AsyncError` portant un `AuthFailure`
/// (connexion) ou un [GuestMergeFailure], sinon `AsyncData`.
///
/// Orchestration entre features (auth, birthday, books, user) : elle
/// vit dans `settings`, qui dépend de chacune, comme la suppression du
/// compte. Se connecter remplace la session d'invité : ses documents sont
/// donc marqués pour le compte choisi avant, puis repris par lui après
/// (`firestore.rules`, skill firebase `schema.md` §10).
class GuestMerge extends AsyncNotifier<void> {
  /// Limite des marques, qui doivent atteindre le serveur avant la
  /// connexion : au-delà, la connexion est trop lente pour s'y risquer.
  static const markTimeout = Duration(seconds: 20);

  @override
  FutureOr<void> build() {}

  /// Marque les données de l'invité, ouvre le compte Google choisi, puis les
  /// y reprend. Renvoie le plan appliqué ; null pour une annulation
  /// (`AsyncData`) ou un échec (`AsyncError`).
  Future<GuestMergePlan?> merge() async {
    if (state.isLoading) return null;
    // La session elle-même, comme le compte ouvert ensuite : l'invité marque
    // ce qui est à lui à cet instant.
    final authRepository = ref.read(authRepositoryProvider);
    final guestUid = authRepository.currentUser?.uid;
    if (guestUid == null) return null;
    final auth = ref.read(authControllerProvider.notifier);
    final birthdays = ref.read(birthdayRepositoryProvider);
    final categories = ref.read(categoryRepositoryProvider);
    final books = ref.read(bookRepositoryProvider);
    final users = ref.read(userRepositoryProvider);
    // En vie jusqu'au bout : la carte disparaît avec l'invité, dès la
    // connexion, avant la reprise.
    final keepAlive = ref.keepAlive();
    state = const AsyncLoading();
    try {
      _GuestData? guest;
      (Object, StackTrace)? markError;
      final opened = await auth.openGoogleAccount((email) async {
        try {
          guest = await _GuestData.mark(
            guestUid,
            email,
            birthdays: birthdays,
            categories: categories,
            books: books,
            users: users,
          ).timeout(markTimeout);
          return true;
        } catch (error, stackTrace) {
          markError = (error, stackTrace);
          return false;
        }
      });
      final marked = guest;
      final targetUid = authRepository.currentUser?.uid;
      if (!opened || marked == null || targetUid == null) {
        if (ref.mounted) {
          state = switch (markError) {
            (final error, final stackTrace) => AsyncError(
              _beforeSignInFailure(error),
              stackTrace,
            ),
            null => _authOutcome(),
          };
        }
        return null;
      }
      try {
        final plan = planGuestMerge(
          guest: marked.birthdays,
          guestGroups: marked.groups,
          target: await birthdays.fetchBirthdays(targetUid),
          targetGroups: await categories.fetchOwnCategories(targetUid),
        );
        await categories.takeOver(
          targetUid,
          guestUid: guestUid,
          copies: plan.newGroups,
          guestGroupIds: [for (final group in marked.groups) group.id],
        );
        await birthdays.takeOver(
          targetUid,
          moves: plan.moves,
          duplicates: plan.duplicates,
        );
        await books.takeOver(targetUid, marked.bookIds);
        if (marked.hasProfile) await users.deleteUser(guestUid);
        if (ref.mounted) state = const AsyncData(null);
        return plan;
      } catch (error, stackTrace) {
        if (ref.mounted) {
          state = AsyncError(GuestMergeFailure.incomplete, stackTrace);
        }
        return null;
      }
    } finally {
      keepAlive.close();
    }
  }

  /// Reprend l'issue publiée par `AuthController` : son échec, ou rien
  /// (annulation).
  AsyncValue<void> _authOutcome() => switch (ref.read(authControllerProvider)) {
    AsyncError(:final error, :final stackTrace) => AsyncError(
      error,
      stackTrace,
    ),
    _ => const AsyncData(null),
  };
}

/// Hors ligne (serveur injoignable, ou marques qui n'arrivent pas), ou autre.
GuestMergeFailure _beforeSignInFailure(Object error) => switch (error) {
  TimeoutException() => GuestMergeFailure.offline,
  FirebaseException(code: 'unavailable') => GuestMergeFailure.offline,
  _ => GuestMergeFailure.failed,
};

/// Données d'un invité, marquées pour le compte qui va les reprendre.
class _GuestData {
  _GuestData({
    required this.birthdays,
    required this.groups,
    required this.bookIds,
    required this.hasProfile,
  });

  /// Marque, comme invité [uid], tout ce qu'il possède pour [email] : lu sur
  /// le serveur d'abord, hors ligne rien n'est écrit.
  static Future<_GuestData> mark(
    String uid,
    String email, {
    required BirthdayRepository birthdays,
    required CategoryRepository categories,
    required BookRepository books,
    required UserRepository users,
  }) async => _GuestData(
    birthdays: await birthdays.markForTransfer(uid, email),
    groups: await categories.markForTransfer(uid, email),
    bookIds: await books.markForTransfer(uid, email),
    hasProfile: await users.markForTransfer(uid, email),
  );

  final List<Birthday> birthdays;
  final List<BirthdayCategory> groups;
  final List<String> bookIds;
  final bool hasProfile;
}

final guestMergeProvider = AsyncNotifierProvider.autoDispose<GuestMerge, void>(
  GuestMerge.new,
);
