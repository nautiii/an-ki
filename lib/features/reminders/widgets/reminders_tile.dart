import 'dart:async';

import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/reminders/domain/reminder_plan.dart';
import 'package:an_ki/features/reminders/providers/reminder_permission.dart';
import 'package:an_ki/features/reminders/widgets/reminder_access_actions.dart';
import 'package:an_ki/features/reminders/widgets/reminder_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ligne « Rappels » des réglages : l'état des rappels sur ce téléphone et,
/// coupés, l'action qui les rétablit — « Activer les rappels » (la boîte
/// système), ou « Ouvrir les réglages » quand seul le téléphone peut les
/// accorder.
class RemindersTile extends ConsumerStatefulWidget {
  const RemindersTile({super.key});

  @override
  ConsumerState<RemindersTile> createState() => _RemindersTileState();
}

class _RemindersTileState extends ConsumerState<RemindersTile>
    with ReminderAccessActions {
  @override
  void initState() {
    super.initState();
    // L'autorisation a pu changer dans les réglages du téléphone depuis la
    // dernière lecture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(reminderPermissionProvider.notifier).refresh());
      }
    });
  }

  @override
  void onRemindersGranted() {
    unawaited(HapticFeedback.lightImpact());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.remindersEnabled)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final permission = ref.watch(reminderPermissionProvider);
    // Illisible, l'autorisation se redemande : c'est aussi le remède.
    final access = permission.hasError
        ? NotificationAccess.denied
        : permission.value;
    final busy = permission.isLoading;

    return ListTile(
      // L'icône face au titre, pas au milieu du texte et du bouton.
      titleAlignment: ListTileTitleAlignment.titleHeight,
      leading: Icon(
        access == NotificationAccess.granted
            ? Icons.notifications_active_rounded
            : Icons.notifications_off_outlined,
      ),
      title: Text(l10n.reminders),
      subtitle: switch (access) {
        null => const Align(
          alignment: AlignmentDirectional.centerStart,
          child: SkeletonBox(height: 12, width: 160),
        ),
        NotificationAccess.granted => Text(
          l10n.remindersSchedule(
            ReminderPolicy.daysBefore,
            context.reminderTime,
          ),
        ),
        NotificationAccess.denied => _Off(
          status: l10n.remindersOff,
          action: l10n.enableReminders,
          onAction: busy ? null : requestReminders,
        ),
        NotificationAccess.blocked => _Off(
          status: l10n.remindersBlocked,
          action: l10n.openAppSettings,
          onAction: busy ? null : openReminderSettings,
        ),
      },
    );
  }
}

/// Rappels coupés : pourquoi, puis l'action qui les rétablit, sous le texte
/// pour tenir en grand texte.
class _Off extends StatelessWidget {
  const _Off({
    required this.status,
    required this.action,
    required this.onAction,
  });

  final String status;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(status),
        const SizedBox(height: AppSpacing.xs),
        FilledButton.tonal(onPressed: onAction, child: Text(action)),
      ],
    );
  }
}
