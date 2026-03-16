import 'package:flutter/material.dart';

import 'contact_tile.dart';

class SectionWidget extends StatelessWidget {
  final String title;

  const SectionWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
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
        const ContactTile(),
        const ContactTile(),
        const SizedBox(height: 20),
      ],
    );
  }
}
