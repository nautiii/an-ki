import 'dart:async';

import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/module_icon.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Module que la carte de découverte présente (Livres).
const discoveredModuleId = 'books';

/// Le module à présenter, ou null : la carte ne s'affiche que si le profil du
/// compte est chargé, n'a aucun choix explicite pour ce module (« Plus tard »
/// et l'interrupteur des Réglages en écrivent un) et que le module est
/// inactif.
final discoverableModuleProvider = Provider<AppModule?>((ref) {
  final uid = ref.watch(currentUidProvider);
  final user = ref.watch(userProfileProvider).value;
  final active = ref.watch(activeModulesProvider);
  if (uid == null || user == null || user.id != uid || active == null) {
    return null;
  }
  if (user.moduleChoices.containsKey(discoveredModuleId)) return null;
  for (final module in ref.watch(appModulesProvider)) {
    if (module.id != discoveredModuleId) continue;
    return active.any((it) => it.id == module.id) ? null : module;
  }
  return null;
});

/// Carte « Nouveau · Livres », une seule fois, après l'agenda (`app/modules`
/// la confie à l'accueil, qui ne connaît pas les modules). Elle dit elle-même
/// si elle a quelque chose à montrer et porte l'écart qui la précède.
///
/// « Essayer » active le module et l'ouvre ; « Plus tard » enregistre
/// `false`, la carte ne revient sur aucun appareil. La ligne « Modules » des
/// Réglages reste le chemin permanent.
class ModuleDiscoveryCard extends ConsumerStatefulWidget {
  const ModuleDiscoveryCard({super.key});

  @override
  ConsumerState<ModuleDiscoveryCard> createState() =>
      _ModuleDiscoveryCardState();
}

class _ModuleDiscoveryCardState extends ConsumerState<ModuleDiscoveryCard> {
  /// Le module que « Essayer » a demandé, gardé à l'écran le temps que
  /// l'activation arrive : le routeur redirige tant que le module est inactif.
  AppModule? _opening;

  /// Un choix vient d'être écrit d'ici : son échec se dit ici aussi, les
  /// Réglages (qui le disent pour leurs écritures) n'étant pas montés.
  bool _wrote = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(activeModulesProvider, (_, active) {
      final opening = _opening;
      if (opening == null || active == null) return;
      if (!active.any((module) => module.id == opening.id)) return;
      _opening = null;
      // Fin de frame, et seulement si l'accueil est devant : une page
      // poussée ou un autre onglet ouvert entre-temps ne doit pas être
      // arraché.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final router = GoRouter.of(context);
        if (router.state.uri.path == AppRoutes.birthdays) {
          router.go(opening.rootPath);
        }
      });
    });
    ref.listenManual(userProfileEditorProvider, (_, next) {
      if (next is AsyncData && _wrote) _wrote = false;
      if (next is! AsyncError || !_wrote) return;
      // Écriture refusée : la carte redevient utilisable, et le dit.
      _wrote = false;
      setState(() => _opening = null);
      // Les Réglages, ouverts par-dessus, le disent déjà pour toute écriture
      // du profil : pas deux messages.
      final path = GoRouter.of(context).state.uri.path;
      if (path.startsWith(AppRoutes.settings)) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.errorUnknown)));
    });
    // Autre compte : ce qui était en cours ne le concerne plus.
    ref.listenManual(currentUidProvider, (_, _) {
      _wrote = false;
      if (_opening != null) setState(() => _opening = null);
    });
  }

  void _try(AppModule module) {
    unawaited(HapticFeedback.selectionClick());
    _wrote = true;
    setState(() => _opening = module);
    // Écriture optimiste : l'activation suit le profil dès le cache.
    unawaited(
      ref
          .read(userProfileEditorProvider.notifier)
          .setModuleEnabled(module.id, enabled: true),
    );
  }

  void _later(AppModule module) {
    unawaited(HapticFeedback.selectionClick());
    _wrote = true;
    unawaited(
      ref
          .read(userProfileEditorProvider.notifier)
          .setModuleEnabled(module.id, enabled: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final module = _opening ?? ref.watch(discoverableModuleProvider);
    if (module == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final busy = _opening != null;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Card(
        // Titre, message et boutons restent des nœuds distincts pour TalkBack.
        semanticContainer: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ModuleIcon(icon: module.selectedIcon),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          l10n.moduleDiscoveryTitle(module.name(l10n)),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.moduleBooksDiscoveryMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Côte à côte, ou l'un sous l'autre quand le texte grossit.
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: AppSpacing.xs,
                overflowSpacing: AppSpacing.xs,
                overflowAlignment: OverflowBarAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => _later(module),
                    child: Text(l10n.moduleDiscoveryLater),
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => _try(module),
                    child: Text(l10n.moduleDiscoveryTry),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
