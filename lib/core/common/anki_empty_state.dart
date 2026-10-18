import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// État vide AnKi : illustration, titre, raison d'agir, action principale et
/// secondaire. Volontairement « dumb » : textes et callbacks viennent de l'écran.
class AnKiEmptyState extends StatelessWidget {
  const AnKiEmptyState({
    super.key,
    required this.illustration,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.primaryIcon,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.footer,
  });

  /// Illustration décorative (ex. `Image.asset(AppAssets.moon)`), exclue de la sémantique.
  final Widget illustration;
  final String title;
  final String message;
  final String? primaryLabel;

  /// Icône devant le libellé de l'action principale.
  final IconData? primaryIcon;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Sous les actions : une précision (ce que l'action lit, par exemple).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: SizedBox.square(dimension: 120, child: illustration),
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (primaryLabel case final label?) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onPrimary,
              icon: switch (primaryIcon) {
                final icon? => Icon(icon),
                null => null,
              },
              label: Text(label, textAlign: TextAlign.center),
            ),
          ],
          if (secondaryLabel case final label?) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(onPressed: onSecondary, child: Text(label)),
          ],
          if (footer case final footer?) ...[
            const SizedBox(height: AppSpacing.sm),
            footer,
          ],
        ],
      ),
    );
  }
}
