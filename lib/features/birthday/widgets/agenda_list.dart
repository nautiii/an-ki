import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/agenda.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/agenda_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// L'agenda de l'accueil, en slivers : une section par période, son en-tête
/// collé sous la barre d'app tant qu'on la parcourt.
class AgendaSliver extends ConsumerWidget {
  const AgendaSliver({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(agendaProvider);
    final today = ref.watch(todayProvider);
    final headerExtent = AgendaSectionHeader.extentFor(context);

    return SliverMainAxisGroup(
      slivers: [
        for (final section in sections)
          SliverMainAxisGroup(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _SectionHeaderDelegate(
                  label: agendaPeriodLabel(context, section.period, today),
                  extent: headerExtent,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                ),
                sliver: SliverList.separated(
                  itemCount: section.birthdays.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final birthday = section.birthdays[index];
                    return AgendaTile(
                      key: ValueKey(birthday.id),
                      birthday: birthday,
                    );
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Libellé d'une période : « Dans les 7 jours », « Novembre », « Janvier 2027 »
/// (l'année seulement quand ce n'est pas celle de [today]).
String agendaPeriodLabel(
  BuildContext context,
  AgendaPeriod period,
  DateTime today,
) {
  final locale = Localizations.localeOf(context).languageCode;
  return switch (period) {
    AgendaSoon() => context.l10n.agendaSoon,
    AgendaMonth(:final year, :final month) => toBeginningOfSentenceCase(
      (year == today.year ? DateFormat.MMMM(locale) : DateFormat.yMMMM(locale))
          .format(DateTime(year, month)),
      locale,
    ),
  };
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SectionHeaderDelegate({required this.label, required this.extent});

  final String label;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      AgendaSectionHeader(label: label);

  @override
  bool shouldRebuild(_SectionHeaderDelegate oldDelegate) =>
      oldDelegate.label != label || oldDelegate.extent != extent;
}

/// En-tête de section, opaque pour que les lignes passent dessous.
class AgendaSectionHeader extends StatelessWidget {
  const AgendaSectionHeader({super.key, required this.label});

  final String label;

  /// Hauteur fixe qu'exige l'en-tête épinglé : elle suit la taille du texte.
  static double extentFor(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall;
    final line = (style?.fontSize ?? 14) * (style?.height ?? 1.43);
    return AppSpacing.md +
        AppSpacing.xs +
        MediaQuery.textScalerOf(context).scale(line);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.md,
          AppSpacing.gutter,
          AppSpacing.xs,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            header: true,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
