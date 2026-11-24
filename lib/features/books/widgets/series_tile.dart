import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/next_volume_status.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Une série dans la liste de l'étagère (dans un `ShelfGroup`) : couverture,
/// nom, statut teinté, trous, dernier tome en gros chiffres (S6). Un seul
/// libellé pour TalkBack, dans l'ordre de l'écran.
///
/// Au-delà de 150 % de texte, la couverture et le numéro passent sur une
/// ligne au-dessus du texte, qui garde toute la largeur.
class SeriesTile extends ConsumerWidget {
  const SeriesTile({super.key, required this.entry, required this.onTap});

  final ShelfEntry entry;
  final VoidCallback onTap;

  /// Largeur de la couverture ; le filet entre deux lignes s'aligne après.
  static const double coverWidth = SeriesCover.defaultWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final today = ref.watch(todayProvider);
    final words = ShelfWords(
      context.l10n,
      Localizations.localeOf(context).languageCode,
    );
    final holes = words.holesLine(entry.holes);
    final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;

    final cover = SeriesCover(
      name: entry.series.name,
      imageUrl: entry.coverUrl,
    );
    final last = entry.last;
    final number = last == null ? null : LastVolumeNumber(number: last);
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.series.name,
          style: textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs),
        SeriesStatusLine(entry: entry, today: today),
        if (holes != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              holes,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );

    return Semantics(
      button: true,
      label: words.seriesLabel(entry, today),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [cover, const Spacer(), ?number],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    identity,
                  ],
                )
              : Row(
                  children: [
                    cover,
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: identity),
                    if (number != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      number,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Le statut du prochain tome, teinté par ce qu'il demande : framboise pour
/// un tome paru (à acheter), nuage pour une date à venir, menthe pour une
/// série terminée, neutre quand on ne sait pas. L'icône double la couleur.
class SeriesStatusLine extends StatelessWidget {
  const SeriesStatusLine({super.key, required this.entry, required this.today});

  final ShelfEntry entry;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final words = ShelfWords(
      context.l10n,
      Localizations.localeOf(context).languageCode,
    );
    final (icon, color) = switch (nextVolumeStatus(entry, today)) {
      NextVolumeStatus.complete => (
        Icons.check_circle_rounded,
        context.ankiColors.success.color,
      ),
      NextVolumeStatus.released => (
        Icons.new_releases_rounded,
        colorScheme.primary,
      ),
      NextVolumeStatus.announced => (Icons.event_rounded, colorScheme.tertiary),
      NextVolumeStatus.unknown => (
        Icons.schedule_rounded,
        colorScheme.onSurfaceVariant,
      ),
    };
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Centre optique de l'icône sur la première ligne de texte.
          padding: EdgeInsets.only(top: AppSpacing.xxs / 2 * scale),
          child: Icon(icon, size: 16 * scale.clamp(1, 1.5), color: color),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            words.nextLine(entry, today),
            style: textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Le dernier tome possédé, en gros chiffres tabulaires (S6). Muet : le
/// libellé de la ligne le dit.
class LastVolumeNumber extends StatelessWidget {
  const LastVolumeNumber({super.key, required this.number, this.large = false});

  final int number;

  /// En tête de la page d'une série : plus grand.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = large
        ? theme.textTheme.displaySmall
        : theme.textTheme.headlineMedium;
    return ExcludeSemantics(
      child: Text(
        '$number',
        style: style?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
