import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Bloc de squelette qui « respire » pendant un chargement, à la forme du
/// contenu attendu. Statique si l'utilisateur a coupé les animations.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = AppRadii.sm,
  });

  final double height;
  final double width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Durations.extralong4,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 1,
          end: 0.55,
        ).animate(CurvedAnimation(parent: _pulse, curve: AppMotion.standard)),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            color: scheme.surfaceContainerHighest,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        ),
      ),
    );
  }
}
