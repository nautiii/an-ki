import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/reminders/providers/reminder_permission.dart';
import 'package:an_ki/features/reminders/providers/reminders_off_notice.dart';
import 'package:an_ki/features/reminders/widgets/reminder_access_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rappels coupés, dit en haut de l'accueil : un état calme et vrai, jamais
/// une relance. « Activer » rouvre la boîte système, ou les réglages du
/// téléphone quand eux seuls peuvent les accorder ; la croix masque la carte
/// pour de bon sur ce téléphone (`remindersOffNoticeProvider`).
///
/// Ne prend aucune place tant qu'il n'y a rien à dire ; affichée, elle porte
/// l'écart qui la sépare de ce qui la suit.
class RemindersOffCard extends ConsumerStatefulWidget {
  const RemindersOffCard({super.key});

  @override
  ConsumerState<RemindersOffCard> createState() => _RemindersOffCardState();
}

class _RemindersOffCardState extends ConsumerState<RemindersOffCard>
    with ReminderAccessActions {
  @override
  void onRemindersGranted() {
    unawaited(HapticFeedback.lightImpact());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.remindersEnabled)));
  }

  void _dismiss() {
    unawaited(ref.read(remindersOffDismissalProvider.notifier).dismiss());
    // Le chemin qui reste, dit une fois.
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.remindersOffHidden)));
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(remindersOffNoticeProvider);
    final busy = ref.watch(
      reminderPermissionProvider.select((permission) => permission.isLoading),
    );

    return AnimatedSize(
      duration: context.motion(AppMotion.enter),
      curve: AppMotion.enterCurve,
      alignment: Alignment.topCenter,
      child: access == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _Notice(
                blocked: access == NotificationAccess.blocked,
                onAction: busy
                    ? null
                    : access == NotificationAccess.blocked
                    ? openReminderSettings
                    : requestReminders,
                onDismiss: _dismiss,
              ),
            ),
    );
  }
}

/// La carte elle-même : l'état, l'action qui le change, la croix.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.blocked,
    required this.onAction,
    required this.onDismiss,
  });

  final bool blocked;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xxs,
          AppSpacing.xxs,
          AppSpacing.xxs,
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.notifications_off_outlined,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.remindersOffNotice,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: onAction,
              child: Text(
                blocked ? l10n.remindersOffSettings : l10n.remindersOffEnable,
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              tooltip: l10n.remindersOffHide,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
