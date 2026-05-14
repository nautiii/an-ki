import 'dart:convert';

import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContactTile extends ConsumerWidget {
  final BirthdayModel birthday;

  const ContactTile({super.key, required this.birthday});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider);

    ImageProvider? backgroundImage;

    if (birthday.picture != null) {
      try {
        backgroundImage = MemoryImage(base64Decode(birthday.picture!));
      } catch (e) {
        backgroundImage = null;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Dismissible(
          key: Key(birthday.id),
          direction: DismissDirection.startToEnd,
          confirmDismiss: (direction) async {
            HapticFeedback.mediumImpact();
            return await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: Text(context.l10n.deleteBirthdayTitle),
                    content: Text(
                      context.l10n.deleteBirthdayConfirmation(
                        "${birthday.name} ${birthday.surname}",
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(context.l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.error,
                        ),
                        child: Text(context.l10n.delete),
                      ),
                    ],
                  ),
            );
          },
          onDismissed: (direction) {
            ref.read(birthdayProvider.notifier).deleteBirthday(birthday.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.l10n.birthdayDeleted(
                    "${birthday.name} ${birthday.surname}",
                  ),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            color: colorScheme.errorContainer,
            child: Icon(Icons.delete_outline, color: colorScheme.error),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: colorScheme.surfaceContainerHigh),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: backgroundImage,
                  child:
                      backgroundImage == null
                          ? Icon(
                            Icons.person,
                            color: colorScheme.onPrimaryContainer,
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${birthday.name} ${birthday.surname}",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      categories.when(
                        data: (allCategories) {
                          final categories =
                              allCategories
                                  .where(
                                    (c) => birthday.categories.contains(c.id),
                                  )
                                  .toList();
                          return Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children:
                                categories.map((cat) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          cat.iconData,
                                          size: 10,
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          cat.getLocalizedName(context),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                          );
                        },
                        loading: () => const SizedBox(),
                        error: (e, s) => const SizedBox(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${birthday.formattedDate} • ${birthday.age} ${context.l10n.yearsOld}",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: colorScheme.onSurfaceVariant),
                  onPressed:
                      () => BirthdayFormSheet.show(
                        context,
                        birthdayToEdit: birthday,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
