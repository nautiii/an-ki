import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/core/common/bottom_bar.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
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

/// Coquille de l'app connectée : l'onglet courant et la barre du bas, un
/// onglet par module actif ([shellTabs]).
///
/// Vit dans `app/` : elle assemble les écrans de plusieurs features, ce
/// qu'aucune feature n'a le droit de faire. Les onglets sont les branches du
/// routeur ([navigationShell]) : chacun garde sa pile et son état.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = shellTabs(
      ref.watch(appModulesProvider),
      ref.watch(activeModulesProvider),
    );
    final current = navigationShell.currentIndex;
    final l10n = context.l10n;

    // La barre est celle du Scaffold racine : les snackbars (toujours
    // affichées par ce Scaffold, même lancées depuis un onglet) se posent
    // au-dessus d'elle. Avec extendBody, le contenu passe sous le verre et
    // reçoit la hauteur de la barre dans son padding du bas.
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: BottomBar(
        destinations: [
          for (final tab in tabs)
            BottomBarDestination(
              icon: tab.module.icon,
              selectedIcon: tab.module.selectedIcon,
              label: tab.module.name(l10n),
            ),
        ],
        // -1 : la branche courante n'a pas d'onglet, aucun n'est surligné.
        selectedIndex: tabs.indexWhere((tab) => tab.branch == current),
        // L'onglet déjà ouvert revient à son écran de départ.
        onSelected: (index) {
          final branch = tabs[index].branch;
          navigationShell.goBranch(branch, initialLocation: branch == current);
        },
      ),
    );
  }
}

/// Onglets de la coquille, tous montés pour garder leur état : seul le
/// courant est visible et actif. Au changement, l'ancien s'efface pendant que
/// le nouveau apparaît en glissant à peine, sauf animations désactivées.
class ShellBranches extends StatefulWidget {
  const ShellBranches({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<ShellBranches> createState() => _ShellBranchesState();
}

class _ShellBranchesState extends State<ShellBranches>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: 1,
  );
  late final Animation<double> _incoming = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _outgoing = CurvedAnimation(
    parent: ReverseAnimation(_controller),
    curve: Curves.easeInCubic,
  );

  /// Onglet qui s'efface pendant la transition.
  int? _previous;

  @override
  void didUpdateWidget(ShellBranches oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _previous = null;
      _controller.value = 1;
      return;
    }
    _previous = oldWidget.currentIndex;
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _previous = null);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final (index, child) in widget.children.indexed)
          _Branch(
            current: index == widget.currentIndex,
            leaving: index == _previous,
            animation: index == widget.currentIndex
                ? _incoming
                : index == _previous
                ? _outgoing
                : kAlwaysCompleteAnimation,
            child: child,
          ),
      ],
    );
  }
}

/// Un onglet, toujours sous la même structure pour ne jamais démonter son
/// navigateur. Caché, il ne peint pas, ne s'anime pas et sort de la
/// sémantique ; celui qui s'efface ne reçoit plus de touches.
class _Branch extends StatelessWidget {
  const _Branch({
    required this.current,
    required this.leaving,
    required this.animation,
    required this.child,
  });

  final bool current;
  final bool leaving;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visible = current || leaving;
    return Offstage(
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: IgnorePointer(
          ignoring: !current,
          child: ExcludeSemantics(
            excluding: !current,
            child: FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.01, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.99, end: 1).animate(animation),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
