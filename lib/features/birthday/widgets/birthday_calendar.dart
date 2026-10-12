import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Calendrier mensuel des anniversaires : une pastille par personne fêtée,
/// la liste du jour en touchant la case.
class BirthdayCalendar extends ConsumerStatefulWidget {
  const BirthdayCalendar({super.key});

  @override
  ConsumerState<BirthdayCalendar> createState() => _BirthdayCalendarState();
}

class _BirthdayCalendarState extends ConsumerState<BirthdayCalendar> {
  late DateTime _focusedDate = ref.read(todayProvider);

  void _moveMonth(int delta) {
    setState(() {
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final birthdays = ref.watch(birthdaysListProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final today = ref.watch(todayProvider);

    return Column(
      children: [
        _CalendarHeader(
          focusedDate: _focusedDate,
          onPrevious: () => _moveMonth(-1),
          onNext: () => _moveMonth(1),
        ),
        const SizedBox(height: AppSpacing.md),
        // Taille de texte bornée dans la grille, comme le sélecteur de date
        // Material : les numéros restent dans leurs cases en grand texte.
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Column(
            children: [
              const _WeekdayHeader(),
              const SizedBox(height: AppSpacing.xs),
              _CalendarGrid(
                focusedDate: _focusedDate,
                today: today,
                birthdays: birthdays,
                categories: categories,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.focusedDate,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime focusedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    // « octobre 2026 » prend une majuscule en tête de calendrier.
    final title = toBeginningOfSentenceCase(
      DateFormat.yMMMM(locale).format(focusedDate),
      locale,
    );

    return Row(
      children: [
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Semantics(
            header: true,
            liveRegion: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        IconButton(
          onPressed: onPrevious,
          tooltip: localizations.previousMonthTooltip,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          onPressed: onNext,
          tooltip: localizations.nextMonthTooltip,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

/// Initiales des jours, à partir du premier jour de la semaine local.
class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final first = localizations.firstDayOfWeekIndex;

    // Initiales ambiguës (« M » : mardi ou mercredi) : chaque case annonce
    // déjà sa date complète. Pas d'écart, comme la grille, pour s'aligner.
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < DateTime.daysPerWeek; i++)
            Expanded(
              child: Text(
                localizations.narrowWeekdays[(first + i) %
                    DateTime.daysPerWeek],
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.focusedDate,
    required this.today,
    required this.birthdays,
    required this.categories,
  });

  /// Retrait visuel de chaque case (l'écart vu à l'écran), dans sa zone de
  /// toucher : sans écart entre elles, 7 cases de 48 dp tiennent sur 336 dp
  /// (360 moins les marges). 2 dp : un réglage optique, hors grille de 8.
  static const double cellInset = 2;

  final DateTime focusedDate;
  final DateTime today;
  final List<Birthday> birthdays;
  final List<BirthdayCategory> categories;

  @override
  Widget build(BuildContext context) {
    final year = focusedDate.year;
    final month = focusedDate.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    // Cases vides avant le 1er, selon le premier jour de la semaine local.
    final leadingDays = DateUtils.firstDayOffset(
      year,
      month,
      MaterialLocalizations.of(context),
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: DateTime.daysPerWeek,
      ),
      itemCount: leadingDays + daysInMonth,
      itemBuilder: (context, index) {
        if (index < leadingDays) return const SizedBox.shrink();

        final date = DateTime(year, month, index - leadingDays + 1);
        final dayBirthdays = birthdays
            .where((b) => DateUtils.isSameDay(b.occurrenceIn(year), date))
            .toList();

        return _CalendarDayCell(
          date: date,
          isToday: DateUtils.isSameDay(date, today),
          birthdays: dayBirthdays,
          categories: categories,
          onTap: dayBirthdays.isEmpty
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  _DayBirthdaysSheet.show(
                    context,
                    date: date,
                    birthdays: dayBirthdays,
                    today: today,
                  );
                },
        );
      },
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.isToday,
    required this.birthdays,
    required this.categories,
    this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final List<Birthday> birthdays;
  final List<BirthdayCategory> categories;
  final VoidCallback? onTap;

  /// Pastilles affichées au plus : la feuille du jour liste tout le monde.
  static const _maxDots = 3;
  static const double _dotSize = 6;

  BirthdayCategory? _categoryOf(Birthday birthday) {
    final id = birthday.categories.firstOrNull;
    return categories.where((category) => category.id == id).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    // Lu par TalkBack : la date complète et les personnes fêtées.
    final label = [
      DateFormat.MMMMEEEEd(locale).format(date),
      for (final birthday in birthdays) '${birthday.name} ${birthday.surname}',
    ].join(', ');

    return Semantics(
      label: label,
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      // Toute la case répond, retrait compris : la cible reste pleine.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(_CalendarGrid.cellInset),
          child: Material(
            color: isToday
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerLow,
            shape: RoundedSuperellipseBorder(
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadii.sm),
              ),
              side: isToday
                  ? BorderSide(color: colorScheme.primary, width: 1.5)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isToday
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  SizedBox(
                    height: _dotSize,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: AppSpacing.xxs,
                      children: [
                        for (final birthday in birthdays.take(_maxDots))
                          DecoratedBox(
                            decoration: ShapeDecoration(
                              shape: const CircleBorder(),
                              color:
                                  _categoryOf(birthday)?.tones(context).color ??
                                  colorScheme.primary,
                            ),
                            child: const SizedBox.square(dimension: _dotSize),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Feuille du jour : les personnes fêtées, avec leur âge.
class _DayBirthdaysSheet extends StatelessWidget {
  const _DayBirthdaysSheet({
    required this.date,
    required this.birthdays,
    required this.today,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime date,
    required List<Birthday> birthdays,
    required DateTime today,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      // Au-dessus de la barre flottante, pas dans l'onglet.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _DayBirthdaysSheet(date: date, birthdays: birthdays, today: today),
    );
  }

  final DateTime date;
  final List<Birthday> birthdays;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                DateFormat.yMMMMd(locale).format(date),
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: birthdays.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: AppSpacing.lg),
                itemBuilder: (context, index) {
                  final birthday = birthdays[index];
                  final picture = birthday.picture;
                  final fullName = '${birthday.name} ${birthday.surname}';
                  return MergeSemantics(
                    child: Row(
                      children: [
                        AnKiAvatar(
                          name: fullName,
                          image: picture != null ? MemoryImage(picture) : null,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fullName, style: textTheme.titleMedium),
                              // Sans année de naissance, le nom seul.
                              if (birthday.ageOn(today) case final age?)
                                Text(
                                  context.l10n.ageInYears(age),
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
