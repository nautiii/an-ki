import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// En-tête de salutation des onglets : salutation, nom, accès aux réglages.
///
/// Volontairement « dumb » : il ne porte aucun état et n'importe aucune feature.
/// Les écrans résolvent la salutation et le nom depuis leurs providers et les
/// passent en paramètres — c'est ce qui permet à ce widget de résider
/// légitimement dans `core/common`.
class Header extends StatelessWidget {
  /// Salutation déjà traduite (« Bonjour », « Bonsoir »).
  final String greeting;

  /// Nom à afficher déjà résolu, ou null pendant son chargement (squelette).
  final String? userName;

  /// Appelé lors d'un appui sur le bouton réglages.
  final VoidCallback onOpenSettings;

  const Header({
    super.key,
    required this.greeting,
    required this.userName,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final actionStyle = IconButton.styleFrom(
      backgroundColor: colorScheme.surfaceContainerHighest,
      foregroundColor: colorScheme.onSurface,
    );

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (userName case final name?)
                Text(name, style: textTheme.headlineMedium)
              else
                // Nom pas encore chargé : un squelette plutôt qu'un texte factice.
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: SkeletonBox(height: 28, width: 120),
                ),
            ],
          ),
        ),
        IconButton(
          style: actionStyle,
          tooltip: context.l10n.settings,
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_rounded),
        ),
      ],
    );
  }
}
