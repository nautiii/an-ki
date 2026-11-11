import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Icône d'un module dans son conteneur tonal, décorative : le nom suit.
class ModuleIcon extends StatelessWidget {
  const ModuleIcon({super.key, required this.icon});

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
