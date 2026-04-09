import 'package:flutter/material.dart';

class BottomBar extends StatelessWidget {
  const BottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon(Icons.cake, color: colorScheme.primary),
          Icon(Icons.list, color: colorScheme.onSurfaceVariant),
          Icon(Icons.settings, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
