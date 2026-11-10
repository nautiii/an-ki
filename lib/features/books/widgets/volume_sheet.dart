import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/shelf_view.dart';
import 'package:an_ki/features/books/widgets/classify_sheet.dart';
import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:an_ki/features/books/widgets/shelf_undo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Feuille d'un tome : couverture, titre, série et numéro, ISBN, date de
/// parution ; le classer (changer de série ou de numéro) ou le retirer, avec
/// « Annuler ». Suit l'étagère : un classement se voit aussitôt, un tome
/// retiré ferme la feuille.
class VolumeSheet extends ConsumerWidget {
  const VolumeSheet({super.key, required this.volumeId});

  final String volumeId;

  /// Ouvre la feuille du tome [volumeId] au-dessus des onglets.
  static Future<void> show(BuildContext context, String volumeId) =>
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => VolumeSheet(volumeId: volumeId),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(volumeByIdProvider(volumeId), (previous, next) {
      final gone =
          previous?.value != null && next.hasValue && next.value == null;
      // Retiré (ici ou ailleurs) : la feuille se ferme, une seule fois.
      if (gone && (ModalRoute.of(context)?.isCurrent ?? false)) {
        Navigator.pop(context);
      }
    });
    final volume = ref.watch(volumeByIdProvider(volumeId)).value;
    if (volume == null) return const SizedBox(height: AppSpacing.xxl);
    final seriesName = switch (volume.seriesId) {
      final id? => ref.watch(seriesEntryProvider(id)).value?.series.name,
      null => null,
    };
    return _VolumeDetails(volume: volume, seriesName: seriesName);
  }
}

class _VolumeDetails extends StatelessWidget {
  const _VolumeDetails({required this.volume, required this.seriesName});

  final Volume volume;

  /// Nom de la série du tome ; null s'il est à classer.
  final String? seriesName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final words = ShelfWords(
      l10n,
      Localizations.localeOf(context).languageCode,
    );
    final title = words.volumeTitle(volume);
    final number = volume.number;
    final classified = seriesName != null && number != null;
    final published = switch (volume.publishedDate) {
      final raw? when raw.trim().isNotEmpty => words.published(raw),
      _ => null,
    };
    final isbn = volume.isbn;
    final lookup = switch (volume.lookup) {
      LookupState.pending => l10n.volumePending,
      LookupState.notFound => l10n.volumeNotFound,
      LookupState.found => null,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              SeriesCover(
                name: seriesName ?? volume.title,
                imageUrl: volume.imageUrl,
                width: 96,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    if (classified) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        l10n.volumeInSeries(seriesName!, number),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    if (volume.authors.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(volume.authors.join(', '), style: secondary),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    if (published != null) Text(published, style: secondary),
                    if (isbn != null)
                      Text(l10n.volumeIsbn(isbn), style: secondary),
                    if (lookup != null) Text(lookup, style: secondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: classified
                ? FilledButton.tonalIcon(
                    onPressed: () => _classify(context),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: Text(l10n.volumeClassify),
                  )
                : FilledButton.icon(
                    onPressed: () => _classify(context),
                    icon: const Icon(Icons.shelves),
                    label: Text(l10n.volumeSort),
                  ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: () {
                removeVolumeWithUndo(context, volume, title: title);
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(l10n.volumeRemove),
            ),
          ),
        ],
      ),
    );
  }

  void _classify(BuildContext context) =>
      unawaited(ClassifySheet.show(context, volume));
}
