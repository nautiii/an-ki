import 'dart:async';
import 'dart:ui';

import 'package:an_ki/core/services/phone_contact_service.dart';
import 'package:an_ki/features/birthday/data/share_service.dart';
import 'package:an_ki/features/birthday/domain/wish_failure.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Souhaiter un anniversaire depuis AnKi : la conversation SMS de la personne
/// reliée à son contact (P5), sinon la feuille de partage du système, puis
/// « souhaité » dès que l'app s'ouvre (SMS) ou qu'une app a été choisie
/// (partage) ; ou l'appeler.
///
/// État : `AsyncLoading` tant que la feuille est ouverte, puis `AsyncData`, ou
/// `AsyncError(WishFailure)`.
class BirthdayWisher extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Envoie [message] : par SMS à [smsTo] quand il est donné (la conversation
  /// s'ouvre, texte prêt), sinon — ou sans app de SMS — par la feuille de
  /// partage. L'app ouverte, ou choisie, marque souhaité l'anniversaire
  /// [birthdayId] de [year] et renvoie vrai ; la feuille fermée sans choix, ou
  /// déjà ouverte, renvoie faux. Lève [WishFailure.shareUnavailable] quand la
  /// feuille ne s'ouvre pas, pour que l'UI choisisse son message.
  Future<bool> wish({
    required String birthdayId,
    required int year,
    required String message,
    Rect? origin,
    String? smsTo,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    if (smsTo != null) {
      final opened = await ref
          .read(phoneContactServiceProvider)
          .sendSms(smsTo, message);
      if (!ref.mounted) return false;
      if (opened) {
        _wished(birthdayId, year);
        return true;
      }
      // Pas d'app de SMS : le partage, qui en propose d'autres.
    }
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
        _wished(birthdayId, year);
        return true;
      case ShareOutcome.dismissed:
        state = const AsyncData(null);
        return false;
      case ShareOutcome.unavailable:
        state = AsyncError(WishFailure.shareUnavailable, StackTrace.current);
        throw WishFailure.shareUnavailable;
    }
  }

  /// Ouvre le composeur avec [number] (n'appelle pas tout seul) : un appel
  /// est aussi un vœu, qui marque souhaité l'anniversaire [birthdayId] de
  /// [year]. Lève [WishFailure.dialUnavailable] sans app de téléphone.
  Future<bool> dial({
    required String birthdayId,
    required int year,
    required String number,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final opened = await ref.read(phoneContactServiceProvider).dial(number);
    if (!ref.mounted) return false;
    if (!opened) {
      state = AsyncError(WishFailure.dialUnavailable, StackTrace.current);
      throw WishFailure.dialUnavailable;
    }
    _wished(birthdayId, year);
    return true;
  }

  void _wished(String birthdayId, int year) {
    state = const AsyncData(null);
    // Écriture optimiste : l'éditeur publie un échec éventuel.
    unawaited(
      ref.read(birthdayEditorProvider.notifier).markWished(birthdayId, year),
    );
  }
}

final birthdayWisherProvider =
    AsyncNotifierProvider.autoDispose<BirthdayWisher, void>(BirthdayWisher.new);
