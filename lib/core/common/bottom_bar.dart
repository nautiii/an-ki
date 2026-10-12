import 'dart:ui';

import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Destination de la [BottomBar] : icônes au repos et sélectionnée, libellé.
class const BottomBarDestination({
  required final IconData icon,
  required final IconData selectedIcon,
  required final String label,
});

/// Barre de navigation flottante en verre dépoli (signature S5).
///
/// Sans état : l'appelant fournit les destinations et l'index sélectionné, et
/// reçoit l'index choisi dans [onSelected] (jamais l'index déjà sélectionné).
/// Chaque destination garde son libellé visible et lu par les lecteurs d'écran.
class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<BottomBarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.ankiColors;
    const radius = BorderRadius.all(Radius.circular(AppRadii.xl));
    // Grand texte : icône au-dessus du libellé, pour garder les libellés entiers.
    final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: const RoundedSuperellipseBorder(borderRadius: radius),
            shadows: colors.floatingShadow,
          ),
          child: ClipRSuperellipse(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.glass,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: radius,
                    side: BorderSide(color: colors.glassBorder),
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Row(
                        children: [
                          for (final (index, destination)
                              in destinations.indexed) ...[
                            if (index > 0) const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: _BottomBarItem(
                                destination: destination,
                                isSelected: index == selectedIndex,
                                stacked: stacked,
                                onTap: () {
                                  if (index == selectedIndex) return;
                                  HapticFeedback.selectionClick();
                                  onSelected(index);
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.destination,
    required this.isSelected,
    required this.stacked,
    required this.onTap,
  });

  final BottomBarDestination destination;
  final bool isSelected;

  /// Icône au-dessus du libellé (grand texte) plutôt qu'à côté.
  final bool stacked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isSelected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;
    final children = [
      Icon(
        isSelected ? destination.selectedIcon : destination.icon,
        color: color,
      ),
      SizedBox(
        width: stacked ? 0 : AppSpacing.xs,
        height: stacked ? AppSpacing.xxs : 0,
      ),
      Flexible(
        child: Text(
          destination.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ];

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: context.motion(AppMotion.tap),
            curve: AppMotion.standard,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: ShapeDecoration(
              color: colorScheme.secondaryContainer.withValues(
                alpha: isSelected ? 1 : 0,
              ),
              shape: stacked
                  ? const RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadii.lg),
                      ),
                    )
                  : const StadiumBorder(),
            ),
            child: stacked
                ? Column(mainAxisSize: MainAxisSize.min, children: children)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: children,
                  ),
          ),
        ),
      ),
    );
  }
}
