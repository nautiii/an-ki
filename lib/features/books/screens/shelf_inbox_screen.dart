import 'dart:async';

import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/placement_suggestion.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/providers/shelf_view.dart';
import 'package:an_ki/features/books/widgets/classify_sheet.dart';
import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:an_ki/features/books/widgets/pending_completer.dart';
import 'package:an_ki/features/books/widgets/volume_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// « À classer » : les tomes sans série ni numéro, le plus récent d'abord ;
/// chacun se range d'un toucher sur la suggestion d'AnKi (`suggestPlacement`,
/// jamais appliquée seule), ou dans une autre série, ou s'ouvre en entier.
class ShelfInboxScreen extends ConsumerWidget {
  const ShelfInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final shelf = ref.watch(shelfProvider);
    final volumes = shelf.value?.unclassified ?? const <Volume>[];
    final intro = ref.watch(inboxHasSuggestionProvider) ? 1 : 0;

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
        // La phrase d'introduction, s'il y a une suggestion à faire, puis
        // un tome par ligne.
        itemCount: volumes.length + intro,
        separatorBuilder: (_, index) =>
            SizedBox(height: index < intro ? AppSpacing.md : AppSpacing.sm),
        itemBuilder: (context, index) => index < intro
            ? Text(
                l10n.inboxIntro,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : _InboxTile(
                key: ValueKey(volumes[index - intro].id),
                volume: volumes[index - intro],
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

/// Un tome à classer : couverture, titre (ou ISBN), auteurs ou état de la
/// recherche ; dessous, le rangement proposé (un toucher) et « ⋯ » pour une
/// autre série. Toucher le tome l'ouvre en entier.
class _InboxTile extends ConsumerWidget {
  const _InboxTile({super.key, required this.volume});

  final Volume volume;

  /// Accepte [suggestion] : le tome rejoint sa série (créée au besoin), et
  /// une snackbar le dit, avec « Voir ».
  void _accept(
    BuildContext context,
    WidgetRef ref,
    PlacementSuggestion suggestion,
  ) {
    final seriesId = ref
        .read(shelfEditorProvider.notifier)
        .place(volume.id, suggestion);
    if (seriesId == null) return;
    unawaited(HapticFeedback.lightImpact());
    // La ligne part aussitôt : le routeur et la snackbar sont lus avant.
    final router = GoRouter.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.inboxPlaced(suggestion.seriesName, suggestion.number),
          ),
          persist: false,
          action: SnackBarAction(
            label: context.l10n.inboxSeeSeries,
            onPressed: () => unawaited(router.push(AppRoutes.series(seriesId))),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final words = ShelfWords(
      l10n,
      Localizations.localeOf(context).languageCode,
    );
    final suggestion = ref.watch(placementSuggestionProvider(volume.id));
    final title = words.volumeTitle(volume);
    final detail = switch (volume.lookup) {
      LookupState.pending => l10n.volumePending,
      LookupState.notFound => l10n.volumeNotFound,
      LookupState.found => volume.authors.join(', '),
    };

    final identity = Semantics(
      button: true,
      label: [title, if (detail.isNotEmpty) detail].join(', '),
      excludeSemantics: true,
      onTap: () => unawaited(VolumeSheet.show(context, volume.id)),
      child: InkWell(
        onTap: () => unawaited(VolumeSheet.show(context, volume.id)),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SeriesCover(name: volume.title, imageUrl: volume.imageUrl),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 3,
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
              ),
            ),
          ],
        ),
      ),
    );

    final Widget primary = switch (suggestion) {
      // Rien à proposer (sans titre, coffret) : le classement complet.
      null => FilledButton.tonalIcon(
        onPressed: () => unawaited(ClassifySheet.show(context, volume)),
        icon: const Icon(Icons.drive_file_move_rounded),
        label: Text(l10n.volumeSort),
      ),
      final suggestion => FilledButton.tonalIcon(
        onPressed: () => _accept(context, ref, suggestion),
        icon: Icon(
          suggestion.isNew
              ? Icons.library_add_rounded
              : Icons.playlist_add_rounded,
        ),
        label: Semantics(
          label: suggestion.isNew
              ? l10n.a11yInboxCreateSeries(
                  suggestion.seriesName,
                  suggestion.number,
                )
              : l10n.a11yInboxPlaceIn(suggestion.seriesName, suggestion.number),
          excludeSemantics: true,
          child: Text(
            suggestion.isNew
                ? l10n.inboxCreateSeries(
                    suggestion.seriesName,
                    suggestion.number,
                  )
                : l10n.inboxPlaceIn(suggestion.seriesName, suggestion.number),
          ),
        ),
      ),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.xxs,
          AppSpacing.sm,
        ),
        // Les actions sur toute la largeur : la suggestion tient sur une
        // ligne, sans couper « t. 13 ».
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
              child: identity,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Flexible(child: primary),
                if (suggestion != null) ...[
                  const SizedBox(width: AppSpacing.xxs),
                  IconButton(
                    onPressed: () =>
                        unawaited(ClassifySheet.show(context, volume)),
                    tooltip: l10n.inboxOtherSeries,
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
