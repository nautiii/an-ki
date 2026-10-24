import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/reminders/providers/reminder_permission.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rétablir les rappels depuis un widget : la boîte système tant qu'elle peut
/// encore s'afficher ([requestReminders]), sinon les réglages du téléphone
/// ([openReminderSettings]), relus au retour dans l'app.
///
/// Le widget dit ce qu'il fait une fois les rappels accordés, d'une façon ou
/// de l'autre, dans [onRemindersGranted].
mixin ReminderAccessActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  late final AppLifecycleListener _lifecycle;

  /// Vrai pendant un passage par les réglages ouverts d'ici.
  bool _inSettings = false;

  /// Les rappels viennent d'être accordés : dans la boîte système, ou dans
  /// les réglages, au retour dans l'app.
  void onRemindersGranted();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Demande l'autorisation et la renvoie, pour la suite propre au widget
  /// (un refus, un blocage).
  Future<NotificationAccess> requestReminders() async {
    final access = await ref
        .read(reminderPermissionProvider.notifier)
        .request();
    if (mounted && access == NotificationAccess.granted) onRemindersGranted();
    return access;
  }

  /// Ouvre les réglages de notification, seule issue une fois bloquées.
  Future<void> openReminderSettings() async {
    _inSettings = true;
    await ref.read(reminderPermissionProvider.notifier).openSettings();
  }

  /// Retour dans l'app : l'autorisation a pu changer dans les réglages.
  Future<void> _onResume() async {
    final access = await ref
        .read(reminderPermissionProvider.notifier)
        .refresh();
    if (!mounted) return;
    if (_inSettings && access == NotificationAccess.granted) {
      onRemindersGranted();
    }
    _inSettings = false;
  }
}
