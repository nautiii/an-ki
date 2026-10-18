import 'dart:async';
import 'dart:ui';

import 'package:an_ki/core/services/share_service.dart';
import 'package:an_ki/features/birthday/domain/wish_failure.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Souhaiter un anniversaire depuis AnKi : la feuille de partage du système,
/// puis « souhaité » dès qu'une app a été choisie.
///
/// État : `AsyncLoading` tant que la feuille est ouverte, puis `AsyncData`, ou
/// `AsyncError(WishFailure.shareUnavailable)`.
class BirthdayWisher extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Partage [message]. Une app choisie marque souhaité l'anniversaire
  /// [birthdayId] de [year] et renvoie vrai ; la feuille fermée sans choix, ou
  /// déjà ouverte, renvoie faux. Lève [WishFailure.shareUnavailable] quand la
  /// feuille ne s'ouvre pas, pour que l'UI choisisse son message.
  Future<bool> wish({
    required String birthdayId,
    required int year,
    required String message,
    Rect? origin,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    ShareOutcome outcome;
    try {
      outcome = await ref
          .read(shareServiceProvider)
          .shareText(message, origin: origin);
    } on Exception {
      // Plugin absent ou erreur de la plateforme : la feuille n'a pas pu
      // s'ouvrir.
      outcome = ShareOutcome.unavailable;
    }
    if (!ref.mounted) return false;
    switch (outcome) {
      case ShareOutcome.shared:
        state = const AsyncData(null);
        // Écriture optimiste : l'éditeur publie un échec éventuel.
        unawaited(
          ref
              .read(birthdayEditorProvider.notifier)
              .markWished(birthdayId, year),
        );
        return true;
      case ShareOutcome.dismissed:
        state = const AsyncData(null);
        return false;
      case ShareOutcome.unavailable:
        state = AsyncError(WishFailure.shareUnavailable, StackTrace.current);
        throw WishFailure.shareUnavailable;
    }
  }
}

final birthdayWisherProvider =
    AsyncNotifierProvider.autoDispose<BirthdayWisher, void>(BirthdayWisher.new);
