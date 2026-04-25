import 'package:an_ki/core/extensions/common_extensions.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:flutter/material.dart';

import 'contact_tile.dart';

class SectionWidget extends StatelessWidget {
  final String title;
  final List<ContactTile> children;
  final VoidCallback? onViewAllPressed;
  final bool isExpanded;
  final bool showViewAll;

  const SectionWidget({
    super.key,
    required this.title,
    required this.children,
    this.onViewAllPressed,
    this.isExpanded = false,
    this.showViewAll = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title.capitalize(),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (showViewAll)
              GestureDetector(
                onTap: onViewAllPressed,
                child: Text(
                  isExpanded ? context.l10n.showLess : context.l10n.viewAll,
                  style: TextStyle(color: colorScheme.primary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 20),
      ],
    );
  }
}
