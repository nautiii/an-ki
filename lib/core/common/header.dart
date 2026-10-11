import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// En-tête de salutation partagé entre les écrans des features.
///
/// Volontairement « dumb » : il ne porte aucun état et n'importe aucune feature.
/// Les écrans résolvent le nom de l'utilisateur / l'état de vue depuis leurs
/// providers et les passent en paramètres — c'est ce qui permet à ce widget de
/// résider légitimement dans `core/common`.
class Header extends StatelessWidget {
  /// Nom à afficher déjà résolu, ou null pendant son chargement (squelette).
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
                context.l10n.hello,
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
        if (showViewToggle) ...[
          IconButton(
            style: actionStyle,
            tooltip: isListView
                ? context.l10n.showCalendar
                : context.l10n.showList,
            onPressed: onToggleView,
            icon: Icon(
              isListView
                  ? Icons.calendar_month_rounded
                  : Icons.view_list_rounded,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
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
