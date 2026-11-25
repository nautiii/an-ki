import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// En-tête commun des feuilles Livres : un visuel à gauche (couverture, tuile
/// date, icône), le titre de la feuille et une ligne d'explication. Le titre
/// est lu comme un titre par TalkBack.
class BookSheetHeader extends StatelessWidget {
  const BookSheetHeader({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    return Row(
      children: [
        leading,
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Le visuel d'une feuille sans couverture : une icône sur une pastille
/// lotus, de la taille d'une couverture d'étagère. Décorative.
class BookSheetIcon extends StatelessWidget {
  const BookSheetIcon({super.key, required this.icon});

  final IconData icon;

  /// Côté de la pastille, celui d'une couverture d'étagère en largeur.
  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colorScheme.secondaryContainer,
            shape: const RoundedSuperellipseBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
            ),
          ),
          child: Icon(icon, color: colorScheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
