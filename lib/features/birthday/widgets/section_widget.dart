import 'package:an_ki/core/extensions/common_extensions.dart';
import 'package:flutter/material.dart';

import 'contact_tile.dart';

class SectionWidget extends StatelessWidget {
  final String title;
  final List<ContactTile> children;

  const SectionWidget({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title.capitalize(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "Voir tout",
              style: TextStyle(color: Colors.orangeAccent),
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
