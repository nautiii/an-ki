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
    final textTheme = Theme.of(context).textTheme;
    final categoriesState = ref.watch(categoriesProvider);

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
        borderRadius: BorderRadius.circular(20),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24),
            color: colorScheme.errorContainer,
            child: Icon(
              Icons.delete_outline_rounded,
              color: colorScheme.error,
              size: 28,
            ),
          ),
          child: Material(
            color: colorScheme.surfaceContainerHigh,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                BirthdayFormSheet.show(context, birthdayToEdit: birthday);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    // Avatar avec bordure subtile
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: colorScheme.primaryContainer,
                        backgroundImage: backgroundImage,
                        child:
                            backgroundImage == null
                                ? Icon(
                                  Icons.person_outline_rounded,
                                  color: colorScheme.onPrimaryContainer,
                                  size: 30,
                                )
                                : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Informations
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${birthday.name} ${birthday.surname}",
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            birthday.getFormattedDate(context),
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          categoriesState.when(
                            data: (allCategories) {
                              final activeCategories =
                                  allCategories
                                      .where(
                                        (c) =>
                                            birthday.categories.contains(c.id),
                                      )
                                      .toList();
                              if (activeCategories.isEmpty) {
                                return const SizedBox();
                              }
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children:
                                      activeCategories.map((cat) {
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primaryContainer
                                                .withValues(alpha: 0.7),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.1),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                cat.iconData,
                                                size: 13,
                                                color:
                                                    colorScheme
                                                        .onPrimaryContainer,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                cat.getLocalizedName(context),
                                                style: textTheme.labelSmall
                                                    ?.copyWith(
                                                      color:
                                                          colorScheme
                                                              .onPrimaryContainer,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 11,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                ),
                              );
                            },
                            loading: () => const SizedBox(),
                            error: (e, s) => const SizedBox(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          birthday.age.toString(),
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: colorScheme.primary,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          context.l10n.yearsOld.toUpperCase(),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
