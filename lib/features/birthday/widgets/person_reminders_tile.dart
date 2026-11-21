import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_reminders_picker.dart';
import 'package:an_ki/features/birthday/widgets/reminder_lead_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Les rappels d'une personne sur une ligne : « Comme d'habitude », « Aucun
/// rappel » ou ses moments (« 7 jours avant · Le jour J »). Un toucher ouvre
/// [PersonRemindersSheet] : la tâche la plus rare de la page n'en prend plus
/// la place.
class PersonRemindersTile extends StatelessWidget {
  const PersonRemindersTile({super.key, required this.birthday});

  final Birthday birthday;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final reminders = birthday.reminders;
    final muted = reminders != null && reminders.isEmpty;

    return Material(
      color: scheme.surfaceContainerLow,
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        // Le nuage : le temps qui vient.
        leading: Icon(
          muted ? Icons.notifications_off_rounded : Icons.notifications_rounded,
          color: scheme.tertiary,
        ),
        title: Text(l10n.reminders),
        subtitle: Text(switch (reminders) {
          null => l10n.birthdayRemindersDefault,
          final leads when leads.isEmpty => l10n.personRemindersNone,
          final leads => context.reminderLeads(leads),
        }),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: scheme.onSurfaceVariant,
        ),
        onTap: () => unawaited(PersonRemindersSheet.show(context, birthday)),
      ),
    );
  }
}

/// Le sélecteur des rappels d'une personne, dans une feuille : chaque choix
/// s'écrit aussitôt, la feuille suit la personne telle qu'elle est.
class PersonRemindersSheet extends ConsumerWidget {
  const PersonRemindersSheet({super.key, required this.birthday});

  /// La personne à l'ouverture, en attendant sa version à jour.
  final Birthday birthday;

  static Future<void> show(BuildContext context, Birthday birthday) =>
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => PersonRemindersSheet(birthday: birthday),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Supprimée pendant que la feuille est ouverte (sur un autre appareil) :
    // la feuille se ferme plutôt que d'écrire sur une personne disparue.
    ref.listen(birthdayByIdProvider(birthday.id), (_, next) {
      if (next case AsyncData(value: null)) Navigator.of(context).pop();
    });
    // La personne à l'ouverture tant que la liste se charge.
    final current =
        ref.watch(birthdayByIdProvider(birthday.id)).value ?? birthday;
    final Set<ReminderLead>? reminders = current.reminders;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.lg,
        ),
        child: BirthdayRemindersPicker(
          reminders: reminders,
          onChanged: (leads) => unawaited(
            ref
                .read(birthdayEditorProvider.notifier)
                .setReminders(current.id, leads),
          ),
        ),
      ),
    );
  }
}
