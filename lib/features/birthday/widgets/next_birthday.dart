import 'dart:convert';

import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NextBirthdayCard extends ConsumerWidget {
  const NextBirthdayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextBirthday = ref.watch(nextBirthdayProvider);
    final isLoading = ref.watch(birthdayProvider.select((s) => s.isLoading));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    ImageProvider? backgroundImage;
    if (nextBirthday?.picture != null) {
      try {
        backgroundImage = MemoryImage(base64Decode(nextBirthday!.picture!));
      } catch (_) {}
    }

    return GestureDetector(
      onTap:
          nextBirthday != null
              ? () {
                HapticFeedback.lightImpact();
                BirthdayFormSheet.show(context, birthdayToEdit: nextBirthday);
              }
              : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorScheme.primary, colorScheme.tertiary],
          ),
        ),
        child: Row(
          children: [
            // Avatar avec bordure lumineuse
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.onPrimary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.2),
                backgroundImage: backgroundImage,
                child:
                    backgroundImage == null
                        ? Icon(
                          Icons.cake_outlined,
                          color: colorScheme.onPrimary,
                          size: 26,
                        )
                        : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _BirthdayContent(
                birthday: nextBirthday,
                isLoading: isLoading,
              ),
            ),
            if (nextBirthday != null && !isLoading) ...[
              const SizedBox(width: 12),
              // Affichage de l'âge (Premium Look)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    nextBirthday.age.toString(),
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onPrimary,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    context.l10n.yearsOld.toUpperCase(),
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BirthdayContent extends StatelessWidget {
  const _BirthdayContent({required this.birthday, required this.isLoading});

  final BirthdayModel? birthday;
  final bool isLoading;

  String _daysLabel(int days, BuildContext context) {
    if (days == 0) return context.l10n.today.toUpperCase();
    if (days == 1) return context.l10n.tomorrow.toUpperCase();
    return context.l10n.inDays(days).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final int? days = birthday?.daysUntilNext;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.nextBirthday.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onPrimary.withValues(alpha: 0.7),
            fontWeight: FontWeight.w800,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if (isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colorScheme.onPrimary,
            ),
          )
        else if (birthday == null)
          Text(
            context.l10n.noBirthdayRegistered,
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          )
        else ...[
          Text(
            '${birthday!.name} ${birthday!.surname}',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _daysLabel(days!, context),
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                birthday!.getFormattedDate(context, includeYear: false),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
