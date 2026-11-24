import 'dart:ui' show ImageFilter;

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:an_ki/features/books/widgets/series_tile.dart';
import 'package:flutter/material.dart';

/// En-tête de la page d'une série : sa couverture floutée en fond sous un
/// voile de surface (une bande lotus sans image), la couverture nette au
/// centre, le nom, le dernier tome en gros chiffres (S6) et « 106 tomes sur
/// 108 ». Lu d'un trait par TalkBack.
class SeriesHeader extends StatelessWidget {
  const SeriesHeader({super.key, required this.entry, required this.topInset});

  final ShelfEntry entry;

  /// Hauteur de la barre d'état et de la barre d'application, sous
  /// lesquelles le fond s'étend.
  final double topInset;

  /// Hauteur du fond flouté ; le voile atteint la surface à son bas.
  static const double backdropHeight = 320;

  /// Largeur de la couverture nette.
  static const double coverWidth = 140;

  /// Opacité du voile de surface en haut du fond (décision du brief : une
  /// seule valeur, dans les deux thèmes).
  static const double veil = 0.55;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.ankiColors;
    final url = entry.coverUrl;
    final hasImage = url != null && url.isNotEmpty;
    final last = entry.last;
    final owned = entry.owned.length;

    final backdrop = ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                // Sous un flou de 32, 64 px de large suffisent.
                cacheWidth: 64,
                // Image en échec (hors ligne sans cache) : la bande lotus.
                errorBuilder: (context, _, _) => ColoredBox(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                // Sur l'image, un voile qui monte à la surface : le texte
                // repose sur une quasi-surface. Sans image, une bande lotus.
                colors: hasImage
                    ? [
                        colorScheme.surface.withValues(alpha: veil),
                        colorScheme.surface,
                      ]
                    : [colorScheme.secondaryContainer, colorScheme.surface],
              ),
            ),
          ),
        ],
      ),
    );

    final cover = DecoratedBox(
      position: DecorationPosition.foreground,
      // Filet : seul relief la nuit, où l'ombre n'existe pas.
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
          side: BorderSide(color: colors.glassBorder),
        ),
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
          ),
          shadows: colors.floatingShadow,
        ),
        child: SeriesCover(
          name: entry.series.name,
          imageUrl: url,
          width: coverWidth,
        ),
      ),
    );

    final label = [
      entry.series.name,
      if (last != null) ...[
        l10n.seriesOwnedOf(owned, last),
        l10n.a11ySeriesLast(last),
      ] else
        l10n.a11ySeriesEmpty,
    ].join(', ');

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: backdropHeight + topInset,
          child: ExcludeSemantics(child: backdrop),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            topInset + AppSpacing.xs,
            AppSpacing.gutter,
            AppSpacing.lg,
          ),
          child: Semantics(
            header: true,
            // Sans titre dans la barre : l'en-tête nomme la page.
            namesRoute: true,
            label: label,
            excludeSemantics: true,
            child: Column(
              children: [
                Center(child: cover),
                const SizedBox(height: AppSpacing.md),
                Text(
                  entry.series.name,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (last != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    children: [
                      LastVolumeNumber(number: last, large: true),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.seriesLastVolumeCaption,
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            l10n.seriesOwnedOf(owned, last),
                            style: textTheme.bodyMedium?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
