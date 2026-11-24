import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/providers/burst_scan.dart';
import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Le ticket du scanner : « Cette session », ce qui vient d'entrer, rangé par
/// série (« One Piece · +2 · tomes 107, 108 »), le plus récent en haut ; les
/// tomes pas encore rangés un par un. Chaque groupe se retire d'un toucher
/// (« Annuler » ensuite) ; un tome rangé dont la série n'a pas les numéros
/// d'avant propose « J'ai aussi les tomes 1 à 106 ».
class BurstTicket extends StatelessWidget {
  const BurstTicket({
    super.key,
    required this.rows,
    required this.onOpenSeries,
    required this.onOpenRow,
    required this.onAddPrevious,
    required this.onRemove,
  });

  final List<BurstRow> rows;

  /// Un groupe de série touché : sa page.
  final ValueChanged<String> onOpenSeries;

  /// Un tome pas encore rangé touché : sa correction.
  final ValueChanged<BurstRow> onOpenRow;

  /// « J'ai aussi les tomes … » d'un tome rangé.
  final ValueChanged<BurstRow> onAddPrevious;

  /// Retire les tomes d'un groupe.
  final ValueChanged<List<BurstRow>> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final groups = burstGroupsOf(rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l10n.burstSessionTitle,
                  style: textTheme.titleLarge,
                ),
              ),
            ),
            // Annoncé par TalkBack à chaque ajout : toujours monté, sinon
            // le premier passe sous silence.
            Semantics(
              liveRegion: true,
              child: Text(
                rows.isEmpty ? '' : l10n.burstCount(rows.length),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: groups.isEmpty
              ? Text(
                  l10n.burstEmpty,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: groups.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final first = group.rows.first;
                    return group.isSeries
                        ? _SeriesGroup(
                            key: ValueKey(first.seriesId),
                            group: group,
                            onOpen: () => onOpenSeries(first.seriesId!),
                            onAddPrevious: onAddPrevious,
                            onRemove: onRemove,
                          )
                        : _LooseRow(
                            key: ValueKey(first.isbn),
                            row: first,
                            onOpen: () => onOpenRow(first),
                            onRemove: onRemove,
                          );
                  },
                ),
        ),
      ],
    );
  }
}

const _groupShape = RoundedSuperellipseBorder(
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
);

/// Les tomes d'une série ajoutés pendant la session.
class _SeriesGroup extends StatelessWidget {
  const _SeriesGroup({
    super.key,
    required this.group,
    required this.onOpen,
    required this.onAddPrevious,
    required this.onRemove,
  });

  final BurstGroup group;
  final VoidCallback onOpen;
  final ValueChanged<BurstRow> onAddPrevious;
  final ValueChanged<List<BurstRow>> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final words = ShelfWords(
      l10n,
      Localizations.localeOf(context).languageCode,
    );
    final first = group.rows.first;
    final name = first.seriesName ?? '';
    final numbers = words.numberList(group.numbers);
    final count = group.rows.length;
    // « J'ai aussi les tomes … » : d'après le plus petit numéro ajouté.
    final lowest = group.rows.reduce(
      (a, b) => (a.number ?? 0) <= (b.number ?? 0) ? a : b,
    );
    final card = colorScheme.surfaceContainerLow;
    return Material(
      color: card,
      shape: _groupShape,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.xxs,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: l10n.a11yBurstGroup(name, count, numbers),
                    excludeSemantics: true,
                    onTap: onOpen,
                    child: InkWell(
                      onTap: onOpen,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(AppRadii.sm),
                      ),
                      child: Row(
                        children: [
                          _CoverWithCheck(
                            name: name,
                            imageUrl: first.coverUrl,
                            ring: card,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: textTheme.titleMedium),
                                Text(
                                  l10n.burstGroupLine(count, numbers),
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onRemove(group.rows),
                  tooltip: l10n.a11yBurstRemoveGroup(name, count, numbers),
                  icon: const Icon(Icons.undo_rounded),
                ),
              ],
            ),
            if (lowest.missingPrevious.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 40 + AppSpacing.xs,
                ),
                child: TextButton.icon(
                  onPressed: () => onAddPrevious(lowest),
                  icon: const Icon(Icons.library_add_rounded),
                  label: Text(
                    previousVolumesLabel(l10n, lowest.missingPrevious),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un tome pas encore rangé : en attente, à classer, introuvable.
class _LooseRow extends StatelessWidget {
  const _LooseRow({
    super.key,
    required this.row,
    required this.onOpen,
    required this.onRemove,
  });

  final BurstRow row;
  final VoidCallback onOpen;
  final ValueChanged<List<BurstRow>> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (row.status) {
      BurstRowStatus.pending => (
        Icons.hourglass_empty_rounded,
        colorScheme.onSurfaceVariant,
      ),
      BurstRowStatus.notFound => (
        Icons.help_outline_rounded,
        colorScheme.error,
      ),
      _ => (Icons.inbox_rounded, colorScheme.tertiary),
    };
    final title = row.title.isEmpty ? row.isbn : row.title;
    return Material(
      color: colorScheme.surfaceContainerLow,
      shape: _groupShape,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onOpen,
        minTileHeight: AppSpacing.xxl,
        contentPadding: const EdgeInsetsDirectional.only(
          start: AppSpacing.md,
          end: AppSpacing.xxs,
        ),
        leading: Icon(icon, color: color),
        title: Text(burstRowText(l10n, row)),
        subtitle: row.status == BurstRowStatus.notFound
            ? Text(l10n.volumeIsbn(row.isbn))
            : null,
        trailing: IconButton(
          onPressed: () => onRemove([row]),
          tooltip: l10n.burstRemove(title),
          icon: const Icon(Icons.undo_rounded),
        ),
      ),
    );
  }
}

/// Couverture 40 et, sur son coin, la pastille menthe « ajouté ».
class _CoverWithCheck extends StatelessWidget {
  const _CoverWithCheck({
    required this.name,
    required this.imageUrl,
    required this.ring,
  });

  final String name;
  final String? imageUrl;

  /// Couleur du fond : un anneau qui détache la pastille de la couverture.
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final success = context.ankiColors.success;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SeriesCover(name: name, imageUrl: imageUrl, width: 40),
        PositionedDirectional(
          end: -AppSpacing.xxs,
          bottom: -AppSpacing.xxs,
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: success.color,
                shape: CircleBorder(side: BorderSide(color: ring, width: 2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                child: Icon(
                  Icons.check_rounded,
                  size: AppSpacing.sm,
                  color: success.onColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Le texte d'une ligne de la rafale.
String burstRowText(AppLocalizations l10n, BurstRow row) =>
    switch (row.status) {
      BurstRowStatus.classified => l10n.burstAdded(
        row.seriesName ?? '',
        row.number ?? 0,
      ),
      BurstRowStatus.pending => l10n.burstPending(row.isbn),
      BurstRowStatus.unclassified => l10n.burstUnclassified(
        row.title.isEmpty ? row.isbn : row.title,
      ),
      BurstRowStatus.notFound => l10n.burstNotFound,
    };

/// La snackbar après le retrait de [rows] : « One Piece, tomes 108 et 109
/// retirés de la collection », ou le titre d'un tome seul.
String burstRemovedText(AppLocalizations l10n, List<BurstRow> rows) {
  final first = rows.first;
  final name = first.seriesName;
  if (first.status == BurstRowStatus.classified && name != null) {
    final numbers = [for (final row in rows) ?row.number]..sort();
    return l10n.burstGroupRemoved(
      name,
      numbers.length,
      numberListOf(l10n, numbers),
    );
  }
  return l10n.volumeRemoved(first.title.isEmpty ? first.isbn : first.title);
}

/// Ce qu'on nomme d'un tome possédé : « One Piece 108 », sinon son titre,
/// sinon son ISBN.
String ownedVolumeText(BurstRow row) {
  if (row.seriesName case final name?) {
    return row.number == null ? name : '$name ${row.number}';
  }
  return row.title.isEmpty ? row.isbn : row.title;
}
