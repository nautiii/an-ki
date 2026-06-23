import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:flutter/material.dart';

/// En-tête de salutation partagé entre les écrans des features.
///
/// Volontairement « dumb » : il ne porte aucun état et n'importe aucune feature.
/// Les écrans résolvent le nom de l'utilisateur / l'état de vue depuis leurs
/// providers et les passent en paramètres — c'est ce qui permet à ce widget de
/// résider légitimement dans `core/common`.
class Header extends StatelessWidget {
  /// Nom à afficher déjà résolu, ou null pour afficher un placeholder.
  final String? userName;

  /// Indique s'il faut afficher le bouton de bascule liste/calendrier.
  final bool showViewToggle;

  /// La vue courante est la liste (contrôle l'icône de bascule).
  final bool isListView;

  /// Appelé lors d'un appui sur la bascule de vue (ignoré si [showViewToggle] est false).
  final VoidCallback? onToggleView;

  /// Appelé lors d'un appui sur le bouton réglages.
  final VoidCallback onOpenSettings;

  const Header({
    super.key,
    required this.userName,
    required this.onOpenSettings,
    this.showViewToggle = true,
    this.isListView = true,
    this.onToggleView,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.hello,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              userName ?? "...",
              style: textTheme.headlineMedium?.copyWith(fontSize: 26),
            ),
          ],
        ),
        Row(
          children: [
            if (showViewToggle) ...[
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(10),
                ),
                onPressed: onToggleView,
                icon: Icon(
                  isListView
                      ? Icons.calendar_month_rounded
                      : Icons.view_list_rounded,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHighest,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(10),
              ),
              onPressed: onOpenSettings,
              icon: Icon(Icons.settings_rounded, color: colorScheme.onSurface),
            ),
          ],
        ),
      ],
    );
  }
}
