import 'dart:async';

import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/module_erase_dialog.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// « Modules » : ce qu'AnKi fait pour l'utilisateur, un interrupteur par
/// module du registre ; un module toujours actif le dit à la place. Sans
/// dialogue : désactiver est réversible, l'interrupteur sert d'annulation, et
/// les données restent. Les effacer passe par un dialogue, sous le module.
///
/// Dans `app/` : l'écran connaît le registre des modules. Ouvert par-dessus
/// les Réglages, qui signalent l'échec d'une écriture du profil.
class ModulesScreen extends ConsumerWidget {
  const ModulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final registry = ref.watch(appModulesProvider);
    final active = ref.watch(activeModulesProvider);
    // Profil du compte illisible (rien en cache, serveur injoignable) : aucun
    // choix ne peut s'enregistrer. Celui d'un compte précédent, gardé
    // pendant un changement de compte, ne compte pas.
    final uid = ref.watch(currentUidProvider);
    final failed = ref.watch(
      userProfileProvider.select(
        (profile) => profile.hasError && profile.value?.id != uid,
      ),
    );

    final Widget body = switch ((failed, active)) {
      (true, _) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AnKiEmptyState(
            illustration: Icon(
              Icons.sync_problem_rounded,
              size: AppSpacing.xxl,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: l10n.modulesErrorTitle,
            message: l10n.errorNetwork,
            primaryLabel: l10n.retry,
            onPrimary: () => ref.invalidate(userProfileProvider),
          ),
        ),
      ),
      (_, final active) => _ModuleList(
        registry: registry,
        activeIds: active == null
            ? null
            : {for (final module in active) module.id},
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.modules)),
      body: SafeArea(top: false, child: body),
    );
  }
}

/// L'introduction, puis les modules dans un même conteneur arrondi.
/// [activeIds] null : l'activation charge, chaque interrupteur attend.
class _ModuleList extends StatelessWidget {
  const _ModuleList({required this.registry, required this.activeIds});

  final List<AppModule> registry;
  final Set<String>? activeIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeIds = this.activeIds;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Text(
            context.l10n.modulesIntro,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, module) in registry.indexed) ...[
                if (index > 0)
                  const Divider(
                    height: 1,
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md,
                  ),
                _ModuleRow(
                  module: module,
                  enabled: activeIds?.contains(module.id),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Un module : son icône dans un conteneur tonal, son nom, ce qu'il fait, et
/// son interrupteur (toute la ligne se touche). Toujours actif, il le dit à
/// la place ; facultatif, il offre d'effacer ses données. [enabled] null :
/// l'activation charge.
class _ModuleRow extends ConsumerWidget {
  const _ModuleRow({required this.module, required this.enabled});

  final AppModule module;
  final bool? enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final name = module.name(l10n);
    final title = Text(name, style: theme.textTheme.titleMedium);
    final subtitle = Text(
      module.description(l10n),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final icon = _ModuleIcon(icon: module.selectedIcon);
    final enabled = this.enabled;
    final canSave = ref.watch(
      userProfileProvider.select((profile) => profile.value != null),
    );

    if (module.alwaysOn) {
      return ListTile(
        leading: icon,
        title: title,
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            subtitle,
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.moduleAlwaysOn,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (enabled == null)
          // Le choix enregistré n'est pas encore connu : la forme de la
          // ligne, et TalkBack l'annonce en chargement.
          Semantics(
            label: l10n.modulesLoading,
            child: ListTile(
              leading: icon,
              title: title,
              subtitle: subtitle,
              trailing: const ExcludeSemantics(
                child: SkeletonBox(height: 32, width: 52, radius: AppRadii.md),
              ),
            ),
          )
        else
          SwitchListTile(
            secondary: icon,
            title: title,
            subtitle: subtitle,
            value: enabled,
            // Sans document de profil (premier lancement hors ligne), rien
            // ne s'enregistrerait : l'interrupteur attend, inactif.
            onChanged: !canSave
                ? null
                : (value) {
                    unawaited(HapticFeedback.selectionClick());
                    // Écriture optimiste : l'interrupteur suit le profil dès
                    // le cache, sans attendre le serveur (hors ligne aussi).
                    unawaited(
                      ref
                          .read(userProfileEditorProvider.notifier)
                          .setModuleEnabled(module.id, enabled: value),
                    );
                  },
          ),
        if (module.data != null)
          Padding(
            // Le texte du bouton (marge interne de 12) aligné sur celui de la
            // ligne : 16 + icône + 16.
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.md + _ModuleIcon.size + AppSpacing.xxs,
              end: AppSpacing.md,
              bottom: AppSpacing.xs,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: () => showModuleEraseDialog(context, module),
                child: Text(l10n.moduleEraseData(name)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Icône d'un module dans son conteneur tonal, décorative : le nom suit.
class _ModuleIcon extends StatelessWidget {
  const _ModuleIcon({required this.icon});

  static const double size = 40;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colorScheme.secondaryContainer,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, color: colorScheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
