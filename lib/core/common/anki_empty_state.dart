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
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// Illustration décorative (ex. `Image.asset(AppAssets.moon)`), exclue de la sémantique.
  final Widget illustration;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

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
          if (primaryLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onPrimary, child: Text(primaryLabel!)),
          ],
          if (secondaryLabel != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          ],
        ],
      ),
    );
  }
}
