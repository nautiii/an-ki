import 'dart:convert';

import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NextBirthdayCard extends ConsumerWidget {
  const NextBirthdayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextBirthday = ref.watch(nextBirthdayProvider);
    final isLoading = ref.watch(birthdayProvider.select((s) => s.isLoading));
    final colorScheme = Theme.of(context).colorScheme;

    ImageProvider? backgroundImage;
    if (nextBirthday?.picture != null) {
      try {
        backgroundImage = MemoryImage(base64Decode(nextBirthday!.picture!));
      } catch (_) {}
    }

    return GestureDetector(
      onTap: nextBirthday != null
          ? () => BirthdayFormSheet.show(context, birthdayToEdit: nextBirthday)
          : null,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.tertiary],
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.2),
              backgroundImage: backgroundImage,
              child: backgroundImage == null
                  ? Icon(
                      Icons.cake_outlined,
                      color: colorScheme.onPrimary,
                      size: 22,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _BirthdayContent(
                birthday: nextBirthday,
                isLoading: isLoading,
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.cake, color: colorScheme.onPrimary),
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
    if (days == 0) return context.l10n.today;
    if (days == 1) return context.l10n.tomorrow;
    return context.l10n.inDays(days);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final DateTime? nextDate = birthday?.nextOccurrence;
    final int? days = birthday?.daysUntilNext;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.nextBirthday,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onPrimary.withValues(alpha: 0.7),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
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
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${_daysLabel(days!, context)} • ${birthday!.getFormattedDate(context, includeYear: false)}',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.7),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
