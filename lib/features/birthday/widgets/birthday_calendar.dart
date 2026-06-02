import 'dart:convert';

import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/category_model.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BirthdayCalendar extends ConsumerStatefulWidget {
  const BirthdayCalendar({super.key});

  @override
  ConsumerState<BirthdayCalendar> createState() => _BirthdayCalendarState();
}

class _BirthdayCalendarState extends ConsumerState<BirthdayCalendar> {
  DateTime _focusedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final birthdays = ref.watch(categoryFilteredBirthdaysProvider);
    final categories = ref.watch(categoriesProvider).value ?? [];
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _CalendarHeader(
          focusedDate: _focusedDate,
          onLeftArrowTap: () {
            setState(() {
              _focusedDate = DateTime(
                _focusedDate.year,
                _focusedDate.month - 1,
              );
            });
          },
          onRightArrowTap: () {
            setState(() {
              _focusedDate = DateTime(
                _focusedDate.year,
                _focusedDate.month + 1,
              );
            });
          },
        ),
        const SizedBox(height: 16),
        _CalendarGrid(
          focusedDate: _focusedDate,
          birthdays: birthdays,
          categories: categories,
        ),
      ],
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  final DateTime focusedDate;
  final VoidCallback onLeftArrowTap;
  final VoidCallback onRightArrowTap;

  const _CalendarHeader({
    required this.focusedDate,
    required this.onLeftArrowTap,
    required this.onRightArrowTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final monthFormat = DateFormat.MMMM(
      Localizations.localeOf(context).languageCode,
    );
    final yearFormat = DateFormat.y(
      Localizations.localeOf(context).languageCode,
    );

    return Row(
      children: [
        const SizedBox(width: 8),
        Text(
          '${monthFormat.format(focusedDate).capitalize()} ${yearFormat.format(focusedDate)}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onLeftArrowTap,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          onPressed: onRightArrowTap,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime focusedDate;
  final List<BirthdayModel> birthdays;
  final List<BirthdayCategory> categories;

  const _CalendarGrid({
    required this.focusedDate,
    required this.birthdays,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(
      focusedDate.year,
      focusedDate.month,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: daysInMonth,
      itemBuilder: (context, index) {
        final day = index + 1;

        final date = DateTime(focusedDate.year, focusedDate.month, day);
        final dayBirthdays =
            birthdays
                .where(
                  (b) => b.date.day == day && b.date.month == focusedDate.month,
                )
                .toList();

        return _CalendarDayCell(
          day: day,
          isToday: DateUtils.isSameDay(date, DateTime.now()),
          birthdays: dayBirthdays,
          categories: categories,
          onTap:
              dayBirthdays.isEmpty
                  ? null
                  : () {
                    HapticFeedback.lightImpact();
                    _showDayBirthdays(context, date, dayBirthdays);
                  },
        );
      },
    );
  }

  void _showDayBirthdays(
    BuildContext context,
    DateTime date,
    List<BirthdayModel> birthdays,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateFormat = DateFormat.yMMMMd(
      Localizations.localeOf(context).languageCode,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  dateFormat.format(date),
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: birthdays.length,
                    separatorBuilder:
                        (context, index) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final birthday = birthdays[index];
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: colorScheme.primaryContainer,
                            backgroundImage:
                                birthday.picture != null
                                    ? MemoryImage(
                                      base64Decode(birthday.picture!),
                                    )
                                    : null,
                            child:
                                birthday.picture == null
                                    ? Icon(
                                      Icons.cake_rounded,
                                      color: colorScheme.primary,
                                    )
                                    : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${birthday.name} ${birthday.surname}",
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "${birthday.age} ${context.l10n.yearsOld}",
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final List<BirthdayModel> birthdays;
  final List<BirthdayCategory> categories;
  final VoidCallback? onTap;

  const _CalendarDayCell({
    required this.day,
    required this.isToday,
    required this.birthdays,
    required this.categories,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color:
              isToday
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border:
              isToday
                  ? Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                  : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 8,
              child: Text(
                day.toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                  color: isToday ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ),
            if (birthdays.isNotEmpty)
              Positioned(
                bottom: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:
                      birthdays.take(4).map((b) {
                        final categoryId =
                            b.categories.isNotEmpty ? b.categories.first : null;
                        final category = categories
                            .cast<BirthdayCategory?>()
                            .firstWhere(
                              (c) => c?.id == categoryId,
                              orElse: () => null,
                            );
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: category?.color ?? colorScheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color: (category?.color ?? colorScheme.primary)
                                    .withValues(alpha: 0.3),
                                blurRadius: 2,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
