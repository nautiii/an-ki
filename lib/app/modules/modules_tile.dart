import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Ligne « Modules · 2 actifs » des Réglages, en fin de préférences : ouvre
/// l'écran Modules, le chemin permanent pour activer ou désactiver un module.
class ModulesTile extends ConsumerWidget {
  const ModulesTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Pas de compte tant que le profil charge : il changerait aussitôt.
    final count = ref.watch(
      activeModulesProvider.select((modules) => modules?.length),
    );

    return ListTile(
      leading: const Icon(Icons.dashboard_customize_rounded),
      title: Text(l10n.modules),
      subtitle: count == null ? null : Text(l10n.modulesActiveCount(count)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push(AppRoutes.modules),
    );
  }
}
