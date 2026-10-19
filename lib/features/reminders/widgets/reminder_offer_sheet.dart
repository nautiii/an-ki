import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/reminders/domain/reminder_offer.dart';
import 'package:an_ki/features/reminders/domain/reminder_plan.dart';
import 'package:an_ki/features/reminders/providers/next_birthday_reminder_provider.dart';
import 'package:an_ki/features/reminders/providers/reminder_permission.dart';
import 'package:an_ki/features/reminders/widgets/reminder_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Proposition d'activer les rappels, par-dessus l'agenda qui vient de se
/// remplir : ce qui vient d'arriver, la cadence, le prochain vrai rappel,
/// puis « Activer les rappels » ou « Plus tard ».
///
/// Un refus dans la boîte système est respecté : la feuille se ferme.
/// Bloquée, l'autorisation ne s'obtient plus que dans les réglages : la
/// feuille y mène, et se ferme d'elle-même au retour si c'est accordé.
class ReminderOfferSheet extends ConsumerStatefulWidget {
  const ReminderOfferSheet({super.key, required this.offer});

  final ReminderOffer offer;

  static Future<void> show(BuildContext context, ReminderOffer offer) =>
      showModalBottomSheet<void>(
        context: context,
        // Au-dessus de la barre flottante, pas dans l'onglet.
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ReminderOfferSheet(offer: offer),
      );

  @override
  ConsumerState<ReminderOfferSheet> createState() => _ReminderOfferSheetState();
}

class _ReminderOfferSheetState extends ConsumerState<ReminderOfferSheet> {
  late final AppLifecycleListener _lifecycle;

  /// Vrai pendant un passage par les réglages ouverts d'ici.
  bool _inSettings = false;

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

  Future<void> _enable() async {
    final access = await ref
        .read(reminderPermissionProvider.notifier)
        .request();
    if (!mounted) return;
    switch (access) {
      case NotificationAccess.granted:
        _closeEnabled();
      case NotificationAccess.denied:
        // « Ne pas autoriser » : la réponse est respectée, sans relance.
        Navigator.pop(context);
      case NotificationAccess.blocked:
        // La feuille passe aux réglages, seule issue désormais.
        break;
    }
  }

  Future<void> _openSettings() async {
    _inSettings = true;
    await ref.read(reminderPermissionProvider.notifier).openSettings();
  }

  /// Retour dans l'app : l'autorisation a pu changer dans les réglages.
  Future<void> _onResume() async {
    final access = await ref
        .read(reminderPermissionProvider.notifier)
        .refresh();
    if (!mounted) return;
    if (_inSettings && access == NotificationAccess.granted) _closeEnabled();
    _inSettings = false;
  }

  /// Ferme la feuille et confirme : les rappels partiront.
  void _closeEnabled() {
    unawaited(HapticFeedback.lightImpact());
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.remindersEnabled;
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final permission = ref.watch(reminderPermissionProvider);
    final blocked = permission.value == NotificationAccess.blocked;
    final reminder = ref.watch(nextBirthdayReminderProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Outcome(offer: widget.offer),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              blocked
                  ? l10n.remindersBlockedTitle
                  : l10n.remindersOfferTitle(ReminderPolicy.daysBefore),
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            blocked
                ? l10n.remindersBlockedMessage
                : l10n.remindersOfferMessage(context.reminderTime),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (reminder != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ReminderPreview(reminder: reminder),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: permission.isLoading
                ? null
                : blocked
                ? _openSettings
                : _enable,
            child: Text(blocked ? l10n.openAppSettings : l10n.enableReminders),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.later),
          ),
        ],
      ),
    );
  }
}

/// Ce qui vient d'arriver : « 12 anniversaires ajoutés », ou retrouvés.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.offer});

  final ReminderOffer offer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final success = context.ankiColors.success;
    return Row(
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 16,
            backgroundColor: success.container,
            child: Icon(
              Icons.check_rounded,
              size: 20,
              color: success.onContainer,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(switch (offer.reason) {
            ReminderOfferReason.added => l10n.birthdaysAdded(offer.count),
            ReminderOfferReason.restored => l10n.remindersOfferRestored(
              offer.count,
            ),
          }, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}

/// Le prochain vrai rappel du jour J, tel que la notification l'affichera :
/// son jour, son titre et son texte, et « Souhaiter » sur Android.
class _ReminderPreview extends StatelessWidget {
  const _ReminderPreview({required this.reminder});

  final PlannedReminder reminder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Lu d'un bloc : « Exemple de rappel », le jour, le titre, le texte.
    return MergeSemantics(
      child: Semantics(
        label: l10n.remindersExample,
        child: Card(
          color: scheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: scheme.primary,
                        child: Icon(
                          Icons.cake_rounded,
                          size: 16,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        l10n.remindersExampleWhen(
                          context.reminderDay(reminder),
                          context.reminderClock(reminder),
                        ),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.notificationBirthdayTitle(reminder.fullName),
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  l10n.notificationBirthdayBody(reminder.name),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                // Le bouton de la notification, Android seulement : ici une
                // image, pas une action.
                if (theme.platform == TargetPlatform.android) ...[
                  const SizedBox(height: AppSpacing.xs),
                  ExcludeSemantics(
                    child: Text(
                      l10n.wish,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
