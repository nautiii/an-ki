import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Une série sur l'étagère : couverture, nom, dernier tome en gros chiffres
/// (S6), ligne « Prochain » et trous. Un seul libellé pour TalkBack, dans
/// l'ordre de l'écran.
///
/// Au-delà de 150 % de texte, la couverture et le numéro passent sur une
/// ligne au-dessus du texte, qui garde toute la largeur.
class SeriesTile extends ConsumerWidget {
  const SeriesTile({super.key, required this.entry, required this.onTap});

  final ShelfEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final words = ShelfWords(
      context.l10n,
      Localizations.localeOf(context).languageCode,
    );
    final holes = words.holesLine(entry.holes);
    final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;
    final secondary = textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

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
        Text(words.nextLine(entry, today), style: secondary),
        if (holes != null)
          Text(
            holes,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.tertiary),
          ),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Semantics(
        button: true,
        label: words.seriesLabel(entry, today),
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [cover, const Spacer(), ?number]),
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
      ),
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
