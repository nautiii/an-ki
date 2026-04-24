import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/providers/birthday_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NextBirthdayCard extends StatelessWidget {
  const NextBirthdayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLoading = context.select(
      (BirthdayProvider provider) => provider.isLoading,
    );
    final List<BirthdayModel> birthdays = context.select(
      (BirthdayProvider provider) => provider.birthdays,
    );
    final BirthdayModel? nextBirthday = birthdays.nextBirthday;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
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
            child: Icon(Icons.cake_outlined, color: colorScheme.onPrimary, size: 22),
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
    );
  }
}

class _BirthdayContent extends StatelessWidget {
  const _BirthdayContent({required this.birthday, required this.isLoading});

  final BirthdayModel? birthday;
  final bool isLoading;

  String _formatDate(DateTime date) => '${date.day} ${months[date.month - 1]}';

  String _daysLabel(int days, BuildContext context) {
    if (days == 0) return context.l10n.today;
    if (days == 1) return context.l10n.tomorrow;
    return context.l10n.inDays(days);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final DateTime? nextDate = birthday?.nextOccurrence;
    final int? days = birthday?.daysUntilNext;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.nextBirthday,
          style: TextStyle(color: colorScheme.onPrimary.withValues(alpha: 0.7)),
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
            style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          )
        else ...[
          Text(
            '${birthday!.surname} ${birthday!.name}',
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${_daysLabel(days!, context)} • ${_formatDate(nextDate!)}',
            style: TextStyle(color: colorScheme.onPrimary.withValues(alpha: 0.7)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
