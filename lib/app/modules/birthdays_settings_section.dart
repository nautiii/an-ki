import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/reminders/providers/reminder_preferences_provider.dart';
import 'package:an_ki/features/reminders/widgets/reminder_preferences_tiles.dart';
import 'package:an_ki/features/reminders/widgets/reminders_tile.dart';
import 'package:an_ki/features/settings/widgets/settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Section « Anniversaires » des Réglages : les rappels (leur état, la
/// cadence, l'heure), l'import des contacts et les groupes.
///
/// Dans `app/` : elle assemble deux features du module (`reminders` et
/// `birthday`), que les Réglages ne connaissent pas.
class BirthdaysSettingsSection extends ConsumerWidget {
  const BirthdaysSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Échec d'une écriture optimiste du réglage des rappels (cadence, heure).
    ref.listen(reminderPreferencesEditorProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.errorUnknown)));
      }
    });
    final l10n = context.l10n;

    return SettingsSection(
      title: l10n.settingsBirthdays,
      children: [
        // L'état des rappels, et de quoi les rétablir s'ils sont coupés.
        const RemindersTile(),
        const ReminderLeadsTile(),
        const ReminderTimeTile(),
        ListTile(
          leading: const Icon(Icons.contact_page_rounded),
          title: Text(l10n.importContacts),
          trailing: const Icon(Icons.chevron_right_rounded),
          // L'aperçu de l'import, qui annonce lui-même ce qu'il ajoute.
          onTap: () => context.push(AppRoutes.contactImport),
        ),
        ListTile(
          leading: const Icon(Icons.label_rounded),
          title: Text(l10n.groups),
          trailing: const Icon(Icons.chevron_right_rounded),
          // Renommer, recolorer ou retirer ses groupes.
          onTap: () => context.push(AppRoutes.groups),
        ),
      ],
    );
  }
}
