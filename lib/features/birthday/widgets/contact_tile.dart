import 'dart:convert';

import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/create_birthday_page.dart';
import 'package:flutter/material.dart';

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
            backgroundImage:
                birthday.picture != null
                    ? MemoryImage(base64Decode(birthday.picture!))
                        as ImageProvider
                    : null,
            child:
                birthday.picture == null
                    ? Icon(Icons.person, color: colorScheme.onPrimaryContainer)
                    : null,
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
                  "${birthday.formattedDate} • ${birthday.age} ${context.l10n.yearsOld}",
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: colorScheme.onSurfaceVariant),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CreateBirthdayPage(birthdayToEdit: birthday),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
