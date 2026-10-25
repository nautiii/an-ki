import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/birthday/widgets/reminder_lead_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Rappels d'une personne dans sa fiche : comme d'habitude (le réglage par
/// défaut), aucun, ou personnalisés — les moments avant le jour J, le jour J
/// restant prévenu.
class BirthdayRemindersPicker extends StatelessWidget {
  const BirthdayRemindersPicker({
    super.key,
    required this.reminders,
    required this.onChanged,
  });

  /// Null : comme d'habitude ; vide : aucun rappel.
  final Set<ReminderLead>? reminders;
  final ValueChanged<Set<ReminderLead>?> onChanged;

  /// Point de départ d'un réglage personnalisé : la cadence d'origine.
  static const _customStart = {ReminderLead.weekBefore, ReminderLead.sameDay};

  void _change(Set<ReminderLead>? reminders) {
    unawaited(HapticFeedback.selectionClick());
    onChanged(reminders);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final reminders = this.reminders;
    final custom = reminders != null && reminders.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.reminders,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              label: Text(l10n.birthdayRemindersDefault),
              selected: reminders == null,
              onSelected: (_) => _change(null),
            ),
            ChoiceChip(
              label: Text(l10n.birthdayRemindersNone),
              selected: reminders != null && reminders.isEmpty,
              onSelected: (_) => _change(const {}),
            ),
            ChoiceChip(
              label: Text(l10n.birthdayRemindersCustom),
              selected: custom,
              onSelected: (_) => custom ? null : _change(_customStart),
            ),
          ],
        ),
        if (custom) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final lead in ReminderLead.values)
                if (lead != ReminderLead.sameDay)
                  FilterChip(
                    label: Text(context.reminderLead(lead)),
                    selected: reminders.contains(lead),
                    onSelected: (selected) => _change(
                      selected
                          ? {...reminders, lead}
                          : ({...reminders}..remove(lead)),
                    ),
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
      ],
    );
  }
}
