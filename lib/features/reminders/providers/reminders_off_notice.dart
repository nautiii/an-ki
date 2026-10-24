import 'package:an_ki/core/services/device_settings.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/reminders/providers/reminder_permission.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Carte « Rappels désactivés » masquée sur ce téléphone, pour de bon : les
/// rappels restent dans les paramètres. L'autorisation tient au téléphone, le
/// masquage aussi.
class RemindersOffDismissal extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.watch(deviceSettingsProvider).remindersOffDismissed();

  /// Masque la carte aussitôt, puis le retient sur l'appareil. Si
  /// l'enregistrement échoue, elle reste masquée le temps de la session.
  Future<void> dismiss() async {
    state = const AsyncData(true);
    try {
      await ref.read(deviceSettingsProvider).dismissRemindersOff();
    } on Exception {
      // Rien à dire à l'utilisateur : la carte reviendra au prochain lancement.
    }
  }
}

final remindersOffDismissalProvider =
    AsyncNotifierProvider<RemindersOffDismissal, bool>(
      RemindersOffDismissal.new,
    );

/// Ce que dit la carte « Rappels désactivés » en haut de l'accueil : les
/// rappels refusés (la boîte système peut encore les accorder) ou bloqués
/// (seuls les réglages le peuvent). Null pour ne rien montrer : rappels
/// accordés ou pas encore lus, agenda vide (rien à rappeler), carte masquée
/// ou masquage pas encore lu.
final remindersOffNoticeProvider = Provider<NotificationAccess?>((ref) {
  final access = ref.watch(reminderPermissionProvider).value;
  if (access == null || access == NotificationAccess.granted) return null;
  if (ref.watch(birthdaysListProvider).isEmpty) return null;
  final dismissed = ref.watch(remindersOffDismissalProvider).value ?? true;
  return dismissed ? null : access;
});
