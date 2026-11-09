import 'dart:async';

import 'package:an_ki/core/providers/user_data_hooks.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/guest_merge_plan.dart';
import 'package:an_ki/features/settings/domain/guest_merge_failure.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ouverture, par un invité, du compte Google qu'AnKi connaît déjà, avec ses
/// anniversaires (B5.5) ; ViewModel de la carte de sauvegarde. Issue :
/// `AsyncLoading` pendant l'opération, `AsyncError` portant un `AuthFailure`
/// (connexion) ou un [GuestMergeFailure], sinon `AsyncData`.
///
/// Orchestration entre features (auth, birthday, user) : elle vit dans
/// `settings`, qui dépend de chacune. Les anniversaires et les groupes y
/// sont repris en propre, avec leur plan de doublons ; les données des
/// autres modules passent par leurs reprises ([guestDataTransfersProvider],
/// fournies par `app/`). Se connecter remplace la session d'invité : ses
/// documents sont donc marqués pour le compte choisi avant, puis repris par
/// lui après (`firestore.rules`, skill firebase `schema.md` §10).
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
    final users = ref.read(userRepositoryProvider);
    final List<GuestDataTransfer> transfers;
    try {
      transfers = ref.read(guestDataTransfersProvider);
    } catch (_, stackTrace) {
      // Reprises que `app/` n'a pas fournies : rien n'est marqué, l'invité
      // reste un invité.
      state = AsyncError(GuestMergeFailure.failed, stackTrace);
      return null;
    }
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
            transfers: transfers,
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
      // Dès le compte ouvert : ce qui est repris, même en partie, se voit.
      _enableGuestModules(users, targetUid, marked.profile);
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
        for (final takeOver in marked.takeOvers) {
          await takeOver(targetUid);
        }
        if (marked.profile != null) await users.deleteUser(guestUid);
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

  /// Active sur le compte [targetUid] les modules que l'invité avait activés,
  /// sans jamais en désactiver : ses données reprises restent visibles, même
  /// si la reprise s'arrête en route. Au mieux : un module resté éteint se
  /// rallume dans les Réglages. Écritures optimistes, non attendues : le
  /// cache les montre tout de suite, l'accusé du serveur peut tarder.
  void _enableGuestModules(
    UserRepository users,
    String targetUid,
    UserProfile? guest,
  ) {
    final choices = guest?.moduleChoices ?? const <String, bool>{};
    for (final MapEntry(key: moduleId, value: enabled) in choices.entries) {
      if (!enabled) continue;
      unawaited(
        users
            .setModuleEnabled(targetUid, moduleId, enabled: true)
            // Profil du compte absent ou refusé : le module reste tel quel.
            .catchError(
              (Object error) => debugPrint(
                '[GuestMerge] module $moduleId not enabled: $error',
              ),
            ),
      );
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
    required this.takeOvers,
    required this.profile,
  });

  /// Marque, comme invité [uid], tout ce qu'il possède pour [email] : ses
  /// anniversaires, ses groupes, les données des autres modules
  /// ([transfers]), puis son profil. Lu sur le serveur d'abord, hors ligne
  /// rien n'est écrit.
  static Future<_GuestData> mark(
    String uid,
    String email, {
    required BirthdayRepository birthdays,
    required CategoryRepository categories,
    required List<GuestDataTransfer> transfers,
    required UserRepository users,
  }) async {
    final guestBirthdays = await birthdays.markForTransfer(uid, email);
    final groups = await categories.markForTransfer(uid, email);
    final takeOvers = [
      for (final transfer in transfers) await transfer(uid, email),
    ];
    return _GuestData(
      birthdays: guestBirthdays,
      groups: groups,
      takeOvers: takeOvers,
      profile: await users.markForTransfer(uid, email),
    );
  }

  final List<Birthday> birthdays;
  final List<BirthdayCategory> groups;

  /// Reprise des données marquées de chaque autre module, une fois le compte
  /// ouvert.
  final List<GuestDataTakeOver> takeOvers;

  /// Profil de l'invité, lu sur le serveur ; null s'il n'en a pas.
  final UserProfile? profile;
}

final guestMergeProvider = AsyncNotifierProvider.autoDispose<GuestMerge, void>(
  GuestMerge.new,
);
