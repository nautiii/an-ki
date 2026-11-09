import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/birthdays_settings_section.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/reminders/providers/reminder_sync_provider.dart';
import 'package:an_ki/features/reminders/widgets/reminders_off_card.dart';
import 'package:an_ki/features/settings/widgets/guest_backup_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Anniversaires : les features `birthday` et `reminders`, toujours actif.
/// L'accueil et son agenda, la section des Réglages (rappels, import,
/// groupes), et la synchro des rappels avec les anniversaires.
final birthdaysModule = AppModule(
  id: 'birthdays',
  alwaysOn: true,
  enabledByDefault: true,
  icon: Icons.cake_outlined,
  selectedIcon: Icons.cake_rounded,
  name: (l10n) => l10n.moduleBirthdays,
  description: (l10n) => l10n.moduleBirthdaysDescription,
  rootPath: AppRoutes.birthdays,
  buildBranch: () => StatefulShellBranch(
    routes: [
      GoRoute(
        path: AppRoutes.birthdays,
        // Les rappels coupés se disent en haut de l'accueil, la sauvegarde
        // d'un invité en fin d'agenda.
        builder: (_, _) => HomeScreen(
          notice: const RemindersOffCard(),
          guestBackup: (count) => GuestBackupCard(count: count),
        ),
      ),
    ],
  ),
  settingsSection: const BirthdaysSettingsSection(),
  effects: [reminderSyncProvider],
  // Les anniversaires, puis les groupes privés. La reprise d'un invité se fait
  // dans `GuestMerge`, qui écarte les doublons.
  data: ModuleData(
    eraser: (ref) {
      final birthdays = ref.watch(birthdayRepositoryProvider);
      final categories = ref.watch(categoryRepositoryProvider);
      return (uid) async {
        await birthdays.deleteAllUserBirthdays(uid);
        await categories.deleteAllUserCategories(uid);
      };
    },
  ),
);
