import 'dart:async';

import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/birthdays_settings_section.dart';
import 'package:an_ki/app/modules/module_discovery.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/data/contact_link_repository.dart';
import 'package:an_ki/features/birthday/domain/contact_link_failure.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/birthday/widgets/add_birthday_sheet.dart';
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
  buildBranch: (_) => StatefulShellBranch(
    routes: [
      GoRoute(
        path: AppRoutes.birthdays,
        // Les rappels coupés se disent en haut de l'accueil, la sauvegarde
        // d'un invité en fin d'agenda, puis la découverte d'un module.
        builder: (_, _) => HomeScreen(
          notice: const RemindersOffCard(),
          guestBackup: (count) => GuestBackupCard(count: count),
          discovery: const ModuleDiscoveryCard(),
        ),
      ),
    ],
  ),
  settingsSection: const BirthdaysSettingsSection(),
  // Le formulaire par défaut, ou l'ajout en une ligne s'il a été choisi.
  primaryAction: ModuleAction(
    icon: Icons.add_rounded,
    label: (l10n) => l10n.addBirthday,
    onPressed: (context, _) => unawaited(AddBirthdaySheet.show(context)),
  ),
  // Ajouter, puis Rechercher, sous « Souhaiter à … » quand il y en a un.
  shortcuts: [
    ModuleShortcut(
      id: 'add',
      icon: 'ic_shortcut_add',
      label: (l10n) => l10n.addBirthday,
      run: (context, _) => unawaited(AddBirthdaySheet.show(context)),
    ),
    ModuleShortcut(
      id: 'search',
      icon: 'ic_shortcut_search',
      label: (l10n) => l10n.searchTooltip,
      run: (context, _) => unawaited(context.push(AppRoutes.search)),
    ),
  ],
  effects: [reminderSyncProvider],
  // Les anniversaires, les groupes privés, puis les liaisons aux contacts de
  // ce téléphone. La reprise d'un invité se fait dans `GuestMerge`, qui
  // écarte les doublons.
  data: ModuleData(
    eraser: (ref) {
      final birthdays = ref.watch(birthdayRepositoryProvider);
      final categories = ref.watch(categoryRepositoryProvider);
      final contactLinks = ref.watch(contactLinkRepositoryProvider);
      return (uid) async {
        await birthdays.deleteAllUserBirthdays(uid);
        await categories.deleteAllUserCategories(uid);
        // Au mieux : un stockage de l'appareil en panne n'empêche pas de
        // supprimer le compte ; ses liaisons restent sous un uid disparu,
        // que personne ne lit plus.
        try {
          await contactLinks.deleteAllUserLinks(uid);
        } on ContactLinkFailure catch (error) {
          debugPrint('[birthdaysModule] contact links not erased: $error');
        }
      };
    },
  ),
);
