import 'dart:async';

import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/widgets/classify_sheet.dart';
import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:an_ki/features/books/widgets/volume_sheet.dart';
import 'package:an_ki/features/books/widgets/pending_completer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// « À classer » : les tomes sans série ni numéro, le plus récent d'abord ;
/// chacun se classe d'un toucher sur « Classer », ou s'ouvre en entier.
class ShelfInboxScreen extends ConsumerWidget {
  const ShelfInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final shelf = ref.watch(shelfProvider);
    final volumes = shelf.value?.unclassified ?? const <Volume>[];

    final Widget body = switch (shelf) {
      AsyncValue(hasError: true, :final error) => Center(
        child: SingleChildScrollView(
          child: AnKiEmptyState(
            illustration: Icon(
              Icons.sync_problem_rounded,
              size: AppSpacing.xxl,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: l10n.shelfErrorTitle,
            message: ShelfWords(
              l10n,
              Localizations.localeOf(context).languageCode,
            ).loadError(error),
            primaryLabel: l10n.retry,
            onPrimary: () => ref
              ..invalidate(bookSeriesProvider)
              ..invalidate(bookVolumesProvider),
          ),
        ),
      ),
      AsyncValue(hasValue: true) when volumes.isEmpty => Center(
        child: SingleChildScrollView(
          child: AnKiEmptyState(
            illustration: Image.asset(AppAssets.moon),
            title: l10n.inboxEmptyTitle,
            message: l10n.inboxEmptyMessage,
          ),
        ),
      ),
      AsyncValue(hasValue: true) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.xs,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
        itemCount: volumes.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) => _InboxTile(
          key: ValueKey(volumes[index].id),
          volume: volumes[index],
        ),
      ),
      _ => Semantics(
        label: l10n.shelfLoading,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Column(
            children: [
              SkeletonBox(height: 96, radius: AppRadii.lg),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(height: 96, radius: AppRadii.lg),
            ],
          ),
        ),
      ),
    };

    return PendingCompleter(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            shelf.hasValue ? l10n.shelfInbox(volumes.length) : l10n.volumeSort,
          ),
        ),
        body: SafeArea(top: false, child: body),
      ),
    );
  }
}

/// Un tome à classer : couverture, titre (ou ISBN), état de la recherche ;
/// « Classer » ouvre le classement, le reste de la ligne le tome.
class _InboxTile extends StatelessWidget {
  const _InboxTile({super.key, required this.volume});

  final Volume volume;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final words = ShelfWords(
      l10n,
      Localizations.localeOf(context).languageCode,
    );
    final title = words.volumeTitle(volume);
    final detail = switch (volume.lookup) {
      LookupState.pending => l10n.volumePending,
      LookupState.notFound => l10n.volumeNotFound,
      LookupState.found => volume.authors.join(', '),
    };

    // Au-delà de 150 % de texte, la ligne s'empile.
    final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;
    final cover = SeriesCover(name: volume.title, imageUrl: volume.imageUrl);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (detail.isNotEmpty)
          Text(
            detail,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    final sort = FilledButton.tonal(
      onPressed: () => unawaited(ClassifySheet.show(context, volume)),
      child: Text(l10n.volumeSort),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => unawaited(VolumeSheet.show(context, volume.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    cover,
                    const SizedBox(height: AppSpacing.xs),
                    text,
                    const SizedBox(height: AppSpacing.xs),
                    sort,
                  ],
                )
              : Row(
                  children: [
                    cover,
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: text),
                    const SizedBox(width: AppSpacing.sm),
                    sort,
                  ],
                ),
        ),
      ),
    );
  }
}
