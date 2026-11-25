import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/shelf_agenda.dart';
import 'package:an_ki/features/books/widgets/release_date_tile.dart';
import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:an_ki/features/books/widgets/shelf_group.dart';
import 'package:flutter/material.dart';

const double _cover = 40;

/// « Prochaines sorties » : trois tomes annoncés au plus, la date la plus
/// proche d'abord. Absente sans date connue (l'appelant ne la montre pas).
class UpcomingReleases extends StatelessWidget {
  const UpcomingReleases({
    super.key,
    required this.releases,
    required this.today,
    required this.onOpen,
  });

  final List<UpcomingRelease> releases;
  final DateTime today;

  /// Ouvre la série du tome.
  final ValueChanged<UpcomingRelease> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShelfSectionLabel(context.l10n.shelfUpcomingTitle, title: true),
        const SizedBox(height: AppSpacing.xs),
        ShelfGroup(
          dividerIndent:
              AppSpacing.md +
              ReleaseDateTile.size +
              AppSpacing.sm +
              _cover +
              AppSpacing.sm,
          children: [
            for (final release in releases)
              _ReleaseRow(
                key: ValueKey(release.entry.series.id),
                release: release,
                today: today,
                onTap: () => onOpen(release),
              ),
          ],
        ),
      ],
    );
  }
}

/// Une sortie : la tuile date, la couverture, « One Piece · tome 109 » et
/// « dans 9 jours ».
class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({
    super.key,
    required this.release,
    required this.today,
    required this.onTap,
  });

  final UpcomingRelease release;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final words = ShelfWords(
      l10n,
      Localizations.localeOf(context).languageCode,
    );
    final name = release.entry.series.name;
    final tile = ReleaseDateTile(date: release.date);
    final cover = SeriesCover(
      name: name,
      imageUrl: release.entry.coverUrl,
      width: _cover,
    );
    final chevron = Icon(
      Icons.chevron_right_rounded,
      color: colorScheme.onSurfaceVariant,
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.shelfVolumeOf(name, release.number),
          style: textTheme.titleMedium,
        ),
        Text(
          words.releaseIn(release.date, today),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;
    return Semantics(
      button: true,
      label: words.releaseLabel(release, today),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        tile,
                        const SizedBox(width: AppSpacing.sm),
                        cover,
                        const Spacer(),
                        chevron,
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    text,
                  ],
                )
              : Row(
                  children: [
                    tile,
                    const SizedBox(width: AppSpacing.sm),
                    cover,
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: text),
                    const SizedBox(width: AppSpacing.xxs),
                    chevron,
                  ],
                ),
        ),
      ),
    );
  }
}
