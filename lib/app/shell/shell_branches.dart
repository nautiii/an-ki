import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Onglets de la coquille : ceux de [live] restent montés pour garder leur
/// état, seul [currentIndex] est visible et actif. Une branche absente de
/// [live] (son module est désactivé) est démontée : ses écrans et leurs
/// abonnements sont libérés. Au changement, l'ancien onglet s'efface pendant
/// que le nouveau apparaît en glissant à peine, sauf animations désactivées.
class ShellBranches extends StatefulWidget {
  const ShellBranches({
    super.key,
    required this.currentIndex,
    required this.children,
    required this.live,
  });

  final int currentIndex;
  final List<Widget> children;

  /// Index des branches à garder montées ; [currentIndex] en fait partie.
  final Set<int> live;

  @override
  State<ShellBranches> createState() => _ShellBranchesState();
}

class _ShellBranchesState extends State<ShellBranches>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.page,
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
          if (widget.live.contains(index))
            _Branch(
              // La clé garde chaque navigateur à sa place quand une autre
              // branche est démontée ou remontée.
              key: ValueKey(index),
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
    super.key,
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
