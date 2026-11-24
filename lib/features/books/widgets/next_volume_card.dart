import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/next_volume_status.dart';
import 'package:an_ki/features/books/domain/release_check.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/widgets/release_date_sheet.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:flutter/material.dart';

/// Le prochain tome sur la page d'une série, selon ce qu'on en sait :
/// - annoncé : carte nuage, la date en grand, « dans 9 jours », la source,
///   « Modifier la date » ;
/// - paru : carte neutre, « Le tome 7 est paru » et « Je l'ai acheté », la
///   seule action pleine de la page ;
/// - inconnu : carte neutre, « Tome 109 · date inconnue », « Ajouter la
///   date » ;
/// - série close : une ligne menthe.
class NextVolumeCard extends StatelessWidget {
  const NextVolumeCard({
    super.key,
    required this.entry,
    required this.today,
    required this.onBought,
  });

  final ShelfEntry entry;
  final DateTime today;

  /// « Je l'ai acheté » sur le tome paru [int].
  final ValueChanged<int> onBought;

  @override
  Widget build(BuildContext context) {
    final words = ShelfWords(
      context.l10n,
      Localizations.localeOf(context).languageCode,
    );
    final number = upcomingVolumeNumber(entry);
    final status = nextVolumeStatus(entry, today);
    if (number == null || status == NextVolumeStatus.complete) {
      return _Complete(words: words);
    }
    return switch (status) {
      NextVolumeStatus.complete => _Complete(words: words),
      NextVolumeStatus.announced => _Announced(
        entry: entry,
        number: number,
        today: today,
        words: words,
      ),
      NextVolumeStatus.released => _Released(
        entry: entry,
        number: number,
        source: words.nextSource(entry, today),
        onBought: () => onBought(number),
      ),
      NextVolumeStatus.unknown => _Unknown(
        entry: entry,
        number: number,
        today: today,
        words: words,
      ),
    };
  }
}

const _card = RoundedSuperellipseBorder(
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
);

/// « Ajouter la date », ou « Modifier la date » pour une date saisie.
class _DateButton extends StatelessWidget {
  const _DateButton({required this.entry, required this.number});

  final ShelfEntry entry;
  final int number;

  @override
  Widget build(BuildContext context) {
    final entered = enteredDateOf(entry);
    return TextButton.icon(
      onPressed: () => unawaited(
        ReleaseDateSheet.show(
          context,
          seriesId: entry.series.id,
          number: number,
          current: entered,
        ),
      ),
      icon: const Icon(Icons.edit_calendar_rounded),
      label: Text(
        entered == null ? context.l10n.nextDateAdd : context.l10n.nextDateEdit,
      ),
    );
  }
}

class _Announced extends StatelessWidget {
  const _Announced({
    required this.entry,
    required this.number,
    required this.today,
    required this.words,
  });

  final ShelfEntry entry;
  final int number;
  final DateTime today;
  final ShelfWords words;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final on = colorScheme.onTertiaryContainer;
    final date = entry.series.next!.date!;
    final source = words.nextSource(entry, today);
    return Material(
      color: colorScheme.tertiaryContainer,
      shape: _card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_rounded, size: 20, color: on),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          context.l10n.nextCardHeading(number),
                          style: textTheme.labelLarge?.copyWith(color: on),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    words.releaseDate(date, today),
                    style: textTheme.headlineMedium?.copyWith(
                      color: on,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!date.isMonthOnly)
                    Text(
                      words.releaseIn(date, today),
                      style: textTheme.bodyLarge?.copyWith(color: on),
                    ),
                  if (source != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.xs,
                      ),
                      child: Text(
                        source,
                        style: textTheme.labelMedium?.copyWith(color: on),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _DateButton(entry: entry, number: number),
            ),
          ],
        ),
      ),
    );
  }
}

class _Released extends StatelessWidget {
  const _Released({
    required this.entry,
    required this.number,
    required this.source,
    required this.onBought,
  });

  final ShelfEntry entry;
  final int number;
  final String? source;
  final VoidCallback onBought;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final source = this.source;
    return Material(
      color: colorScheme.surfaceContainerHigh,
      shape: _card,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.new_releases_rounded, color: colorScheme.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.nextCardOut(number),
                          style: textTheme.titleMedium,
                        ),
                        if (source != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xxs),
                            child: Text(
                              source,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Une date dépassée rend le tome « paru » : elle reste
            // corrigeable (sortie repoussée, source qui se trompe).
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _DateButton(entry: entry, number: number),
                FilledButton.icon(
                  onPressed: onBought,
                  icon: const Icon(Icons.check_rounded),
                  label: Semantics(
                    label: l10n.a11ySeriesBought(number),
                    excludeSemantics: true,
                    child: Text(l10n.seriesBought),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Unknown extends StatelessWidget {
  const _Unknown({
    required this.entry,
    required this.number,
    required this.today,
    required this.words,
  });

  final ShelfEntry entry;
  final int number;
  final DateTime today;
  final ShelfWords words;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final source = words.nextSource(entry, today);
    return Material(
      color: colorScheme.surfaceContainerHigh,
      shape: _card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          words.nextCard(entry, today),
                          style: textTheme.titleMedium,
                        ),
                        if (source != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              top: AppSpacing.xxs,
                              end: AppSpacing.xs,
                            ),
                            child: Text(
                              source,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _DateButton(entry: entry, number: number),
            ),
          ],
        ),
      ),
    );
  }
}

class _Complete extends StatelessWidget {
  const _Complete({required this.words});

  final ShelfWords words;

  @override
  Widget build(BuildContext context) {
    final success = context.ankiColors.success;
    final textTheme = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: success.color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              words.l10n.nextCardComplete,
              style: textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
