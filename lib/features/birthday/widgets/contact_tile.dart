import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:flutter/material.dart';

import '../../../data/models/birthday_model.dart';

class ContactTile extends StatelessWidget {
  final BirthdayModel birthday;

  const ContactTile({super.key, required this.birthday});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(Icons.person, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${birthday.name} ${birthday.surname}",
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "${birthday.formattedDate} • ${birthday.age} ans",
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: colorScheme.onSurfaceVariant),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
