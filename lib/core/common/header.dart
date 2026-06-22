import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:flutter/material.dart';

/// Greeting header shared across feature screens.
///
/// Deliberately dumb: it owns no state and imports no feature. Screens resolve
/// the user name / view state from their providers and pass them in, which is
/// why this widget can legitimately live in `core/common`.
class Header extends StatelessWidget {
  /// Resolved display name, or null to show a placeholder.
  final String? userName;

  /// Whether to show the list/calendar view toggle.
  final bool showViewToggle;

  /// Current view is the list (controls the toggle icon).
  final bool isListView;

  /// Called when the view toggle is pressed (ignored when [showViewToggle] is false).
  final VoidCallback? onToggleView;

  /// Called when the settings button is pressed.
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
