import 'dart:async';

import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/birthday/widgets/reminder_lead_display.dart';
import 'package:an_ki/features/reminders/providers/reminder_preferences_provider.dart';
import 'package:an_ki/features/reminders/widgets/reminder_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// « Me prévenir » : les rappels avant le jour J, cochés dès le toucher. Le
/// jour J n'a pas de puce, il est toujours prévenu.
class ReminderLeadsTile extends ConsumerWidget {
  const ReminderLeadsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final leads = ref.watch(
      effectiveReminderPreferencesProvider.select(
        (preferences) => preferences?.leads,
      ),
    );

    return ListTile(
      titleAlignment: ListTileTitleAlignment.titleHeight,
      leading: const Icon(Icons.event_repeat_rounded),
      title: Text(l10n.remindersWhen),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xs),
          if (leads == null)
            const SkeletonBox(height: 32, width: 200)
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final lead in ReminderLead.values)
                  if (lead != ReminderLead.sameDay)
                    FilterChip(
                      label: Text(context.reminderLead(lead)),
                      selected: leads.contains(lead),
                      onSelected: (_) {
                        unawaited(HapticFeedback.selectionClick());
                        // Écriture optimiste : un échec est signalé par
                        // l'écran des réglages.
                        unawaited(
                          ref
                              .read(reminderPreferencesEditorProvider.notifier)
                              .toggleLead(lead),
                        );
                      },
                    ),
              ],
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.remindersSameDayAlways,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// « Heure des rappels » : la même pour tous, choisie dans l'horloge du
/// système.
class ReminderTimeTile extends ConsumerWidget {
  const ReminderTimeTile({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final preferences = ref.read(effectiveReminderPreferencesProvider);
    if (preferences == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: preferences.hour,
        minute: preferences.minute,
      ),
    );
    if (picked == null || !context.mounted) return;
    unawaited(
      ref
          .read(reminderPreferencesEditorProvider.notifier)
          .setTime(hour: picked.hour, minute: picked.minute),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(effectiveReminderPreferencesProvider);

    return ListTile(
      leading: const Icon(Icons.schedule_rounded),
      title: Text(context.l10n.remindersTime),
      trailing: preferences == null
          ? const SkeletonBox(height: 16, width: 48)
          : Text(
              context.reminderTime(preferences),
              style: Theme.of(context).textTheme.titleMedium,
            ),
      onTap: preferences == null ? null : () => _pick(context, ref),
    );
  }
}
