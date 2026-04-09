import 'package:an_ki/core/extensions/common_extensions.dart';
import 'package:flutter/material.dart';

import 'contact_tile.dart';

class SectionWidget extends StatelessWidget {
  final String title;
  final List<ContactTile> children;

  const SectionWidget({super.key, required this.title, required this.children});

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
            Text(
              "Voir tout",
              style: TextStyle(color: colorScheme.primary),
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
