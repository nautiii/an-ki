import 'package:an_ki/core/services/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Autorisation des notifications, donc des rappels, et ses actions : la
/// demander, ouvrir les réglages, la relire au retour dans l'app.
///
/// État : l'autorisation connue ; `AsyncLoading` (qui garde la précédente)
/// pendant une demande. Elle tient à l'appareil, pas au compte : elle
/// survit aux changements de session.
class ReminderPermission extends AsyncNotifier<NotificationAccess> {
  @override
  Future<NotificationAccess> build() =>
      ref.watch(notificationServiceProvider).access();

  /// Demande l'autorisation (la boîte système quand elle peut encore
  /// s'afficher) et la renvoie, pour la réaction immédiate de l'écran. Un
  /// appel pendant une demande est ignoré.
  Future<NotificationAccess> request() async {
    final known = state.value ?? NotificationAccess.denied;
    if (state.isLoading) return known;
    final notifications = ref.read(notificationServiceProvider);
    state = const AsyncLoading();
    final access = await notifications.requestAccess();
    if (ref.mounted) state = AsyncData(access);
    return access;
  }

  /// Relit l'autorisation au retour dans l'app (réglages, autre app) et la
  /// renvoie. Un blocage connu le reste tant que rien n'est accordé : la
  /// simple lecture ne le voit pas.
  Future<NotificationAccess> refresh() async {
    final known = state.value;
    if (state.isLoading) return known ?? NotificationAccess.denied;
    final read = await ref.read(notificationServiceProvider).access();
    // Une demande a pu commencer pendant la lecture : elle décidera.
    if (!ref.mounted || state.isLoading) return read;
    final access =
        read == NotificationAccess.denied && known == NotificationAccess.blocked
        ? NotificationAccess.blocked
        : read;
    state = AsyncData(access);
    return access;
  }

  /// Ouvre les réglages de notification de l'app.
  Future<void> openSettings() =>
      ref.read(notificationServiceProvider).openSettings();
}

final reminderPermissionProvider =
    AsyncNotifierProvider<ReminderPermission, NotificationAccess>(
      ReminderPermission.new,
    );
