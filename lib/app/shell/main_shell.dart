import 'dart:async';

import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/module_redirect_notice.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/app/shell/shell_branches.dart';
import 'package:an_ki/core/common/bottom_bar.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Onglet de la barre : un module, et l'index de sa branche dans le routeur.
typedef ShellTab = ({AppModule module, int branch});

/// Onglets de la barre, dans l'ordre du [registry] : les modules [active],
/// chacun avec l'index de sa branche, sa place dans le registre. L'index d'un
/// onglet dans la barre peut donc différer de celui de sa branche.
List<ShellTab> shellTabs(List<AppModule> registry, List<AppModule> active) {
  final activeIds = {for (final module in active) module.id};
  return [
    for (final (branch, module) in registry.indexed)
      if (activeIds.contains(module.id)) (module: module, branch: branch),
  ];
}

/// Branche à montrer quand le routeur est sur [current] : elle-même si son
/// module tourne, sinon celle du premier onglet. La coquille y passe dès
/// qu'elle est au premier plan ; d'ici là, rien d'un module désactivé ne
/// s'affiche.
int shownBranch(List<ShellTab> tabs, int current) =>
    tabs.any((tab) => tab.branch == current) || tabs.isEmpty
    ? current
    : tabs.first.branch;

/// Coquille de l'app connectée : l'onglet courant et la barre du bas, un
/// onglet par module qui tourne ([shellTabs], [runningModulesProvider]) ;
/// pas de barre pour un seul module.
///
/// Vit dans `app/` : elle assemble les écrans de plusieurs features, ce
/// qu'aucune feature n'a le droit de faire. Les onglets sont les branches du
/// routeur ([navigationShell]) : chacun garde sa pile et son état tant que son
/// module est actif.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  /// Branches désactivées depuis leur dernière visite : rouvertes, elles
  /// repartent de leur racine.
  final _restart = <int>{};

  /// Module activé depuis la snackbar d'une redirection, à ouvrir dès qu'il
  /// est actif.
  AppModule? _openWhenActive;

  @override
  void initState() {
    super.initState();
    // Une redirection notée avant que la coquille soit là (démarrage) est
    // annoncée à son arrivée.
    ref.listenManual(moduleRedirectNoticeProvider, (_, module) {
      if (module == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _announceRedirect(module);
      });
    }, fireImmediately: true);
  }

  /// « Le module Livres est désactivé · Activer ».
  void _announceRedirect(AppModule module) {
    ref.read(moduleRedirectNoticeProvider.notifier).clear();
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.moduleDisabledNotice(module.name(l10n))),
          persist: false,
          action: SnackBarAction(
            label: l10n.moduleEnable,
            onPressed: () {
              _openWhenActive = module;
              unawaited(
                ref
                    .read(userProfileEditorProvider.notifier)
                    .setModuleEnabled(module.id, enabled: true),
              );
            },
          ),
        ),
      );
  }

  /// Une vérification de la branche courante est déjà prévue pour la fin du
  /// frame.
  bool _checkScheduled = false;

  /// La coquille est la page du dessus : aucune page (Réglages, recherche)
  /// ni dialogue ouvert par-dessus. Une navigation de la coquille remplace la
  /// pile : couverte, elle fermerait ces pages.
  bool get _inFront => ModalRoute.isCurrentOf(context) ?? true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dépend de la page du dessus : revenue devant, la coquille quitte la
    // branche d'un module désactivé entre-temps.
    if (_inFront) _leaveInactiveBranch();
  }

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _leaveInactiveBranch();
  }

  /// Ouvre la branche [branch] : à sa racine si on y est déjà, si son module
  /// a été désactivé depuis, ou si [restart] ; sinon là où on l'avait
  /// laissée.
  void _open(int branch, {bool restart = false}) {
    final shell = widget.navigationShell;
    final fromRoot =
        restart || _restart.remove(branch) || branch == shell.currentIndex;
    shell.goBranch(branch, initialLocation: fromRoot);
  }

  /// Le module de la branche courante ne tourne plus : la coquille passe au
  /// premier onglet, en fin de frame, une fois l'activation connue (tant que
  /// le profil charge, ce module peut encore se révéler actif) et au premier
  /// plan. Couverte, elle attend son retour devant ([didChangeDependencies]).
  void _leaveInactiveBranch() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted || !_inFront) return;
      if (ref.read(activeModulesProvider) == null) return;
      final tabs = shellTabs(
        ref.read(appModulesProvider),
        ref.read(runningModulesProvider),
      );
      final current = widget.navigationShell.currentIndex;
      final shown = shownBranch(tabs, current);
      if (shown != current) _open(shown);
    });
  }

  /// Activé depuis la snackbar : ouvert dès que le profil le dit actif, si
  /// la coquille est encore devant ; sinon l'ouverture est abandonnée.
  void _openPending(List<AppModule>? active) {
    final pending = _openWhenActive;
    if (pending == null || !(active?.contains(pending) ?? false)) return;
    _openWhenActive = null;
    if (!_inFront) return;
    // En fin de frame : le routeur a alors appris que le module est actif,
    // et ne le redirige plus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_inFront) return;
      _open(ref.read(appModulesProvider).indexOf(pending), restart: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(appModulesProvider);
    final tabs = shellTabs(registry, ref.watch(runningModulesProvider));
    ref
      ..listen(runningModulesProvider, (previous, next) {
        // Démontée, une branche désactivée repart de sa racine à son retour.
        final running = {
          for (final tab in shellTabs(registry, next)) tab.branch,
        };
        for (final tab in shellTabs(registry, previous ?? const [])) {
          if (!running.contains(tab.branch)) _restart.add(tab.branch);
        }
        _leaveInactiveBranch();
      })
      ..listen(activeModulesProvider, (_, active) {
        _leaveInactiveBranch();
        _openPending(active);
      });
    final shown = shownBranch(tabs, widget.navigationShell.currentIndex);
    final l10n = context.l10n;

    // La barre est celle du Scaffold racine : les snackbars (toujours
    // affichées par ce Scaffold, même lancées depuis un onglet) se posent
    // au-dessus d'elle. Avec extendBody, le contenu passe sous le verre et
    // reçoit la hauteur de la barre dans son padding du bas. Un seul module :
    // pas de barre, le contenu et les snackbars descendent jusqu'en bas.
    return Scaffold(
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: tabs.length < 2
          ? null
          : BottomBar(
              destinations: [
                for (final tab in tabs)
                  BottomBarDestination(
                    icon: tab.module.icon,
                    selectedIcon: tab.module.selectedIcon,
                    label: tab.module.name(l10n),
                  ),
              ],
              selectedIndex: tabs.indexWhere((tab) => tab.branch == shown),
              onSelected: (index) => _open(tabs[index].branch),
            ),
    );
  }
}

/// Branches de la coquille selon les modules qui tournent : celle de
/// [currentIndex], ou du premier onglet si son module ne tourne plus, est
/// montrée ; celles des modules désactivés sont démontées, sauf la courante
/// tant que la coquille ne l'a pas quittée ([MainShell]).
class ModuleBranches extends ConsumerWidget {
  const ModuleBranches({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = shellTabs(
      ref.watch(appModulesProvider),
      ref.watch(runningModulesProvider),
    );
    return ShellBranches(
      currentIndex: shownBranch(tabs, currentIndex),
      live: {for (final tab in tabs) tab.branch, currentIndex},
      children: children,
    );
  }
}
