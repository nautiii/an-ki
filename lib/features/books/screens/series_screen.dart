import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/next_volume_status.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/providers/shelf_offline.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/providers/shelf_view.dart';
import 'package:an_ki/features/books/widgets/offline_banner.dart';
import 'package:an_ki/features/books/widgets/series_actions.dart';
import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:an_ki/features/books/widgets/series_tile.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:an_ki/features/books/widgets/volume_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Page d'une série : couverture, nom, dernier tome en gros chiffres ; la
/// carte « Prochain » ; les tomes manquants ; la grille des numéros. Son menu
/// renomme, fusionne, marque terminée ou supprime la série.
///
/// Un id inconnu (série supprimée, fusionnée, d'un autre compte) a son propre
/// message ; une série qui disparaît pendant qu'on la regarde ferme la page.
class SeriesScreen extends ConsumerWidget {
  const SeriesScreen({super.key, required this.seriesId});

  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entry = ref.watch(seriesEntryProvider(seriesId));
    ref.listen(seriesEntryProvider(seriesId), (previous, next) {
      final gone =
          previous?.value != null && next.hasValue && next.value == null;
      if (!gone) return;
      // Supprimée ou fusionnée : la page se ferme, avec ce qui est ouvert
      // par-dessus (dialogue, feuille).
      final page = ModalRoute.of(context);
      final navigator = Navigator.of(context);
      if (page != null) navigator.popUntil((route) => route == page);
      if (navigator.canPop()) navigator.pop();
    });
    final offline = ref.watch(shelfOfflineProvider);

    final Widget body = switch (entry) {
      AsyncValue(hasError: true, :final error) => _Message(
        illustration: Icon(
          Icons.sync_problem_rounded,
          size: AppSpacing.xxl,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: l10n.seriesErrorTitle,
        message: ShelfWords(
          l10n,
          Localizations.localeOf(context).languageCode,
        ).loadError(error),
        actionLabel: l10n.retry,
        onAction: () => ref
          ..invalidate(bookSeriesProvider)
          ..invalidate(bookVolumesProvider),
      ),
      AsyncValue(hasValue: true, :final value) when value != null =>
        _SeriesDetails(entry: value, offline: offline),
      AsyncValue(hasValue: true) => _Message(
        illustration: Image.asset(AppAssets.moon),
        title: l10n.seriesMissingTitle,
        message: l10n.seriesMissingMessage,
        actionLabel: l10n.seriesBackToShelf,
        onAction: () => context.go(AppRoutes.books),
      ),
      _ => const _LoadingHeader(),
    };

    return Scaffold(
      appBar: AppBar(
        // Le nom de la série reste lisible au défilement, et pour TalkBack.
        title: switch (entry.value) {
          final value? => Text(value.series.name),
          null => null,
        },
        actions: [
          if (entry.value case final value?) SeriesMenu(entry: value),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

class _SeriesDetails extends ConsumerWidget {
  const _SeriesDetails({required this.entry, required this.offline});

  final ShelfEntry entry;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final words = ShelfWords(
      l10n,
      Localizations.localeOf(context).languageCode,
    );

    return CustomScrollView(
      slivers: [
        if (offline) const SliverToBoxAdapter(child: OfflineBanner()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xs,
            AppSpacing.gutter,
            0,
          ),
          sliver: SliverList.list(
            children: [
              _Header(entry: entry, today: today, words: words),
              const SizedBox(height: AppSpacing.lg),
              _NextCard(entry: entry, today: today, words: words),
              if (entry.holes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _SectionTitle(l10n.seriesHolesTitle),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final hole in entry.holes)
                      Chip(label: Text(l10n.seriesHoleChip(hole))),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _SectionTitle(l10n.seriesVolumesTitle),
              const SizedBox(height: AppSpacing.xs),
              if (entry.last == null)
                Text(
                  l10n.seriesNoVolume,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (entry.last != null)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            sliver: VolumeGrid(entry: entry),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }
}

/// Couverture, nom et dernier tome ; lus d'un trait par TalkBack.
class _Header extends StatelessWidget {
  const _Header({
    required this.entry,
    required this.today,
    required this.words,
  });

  final ShelfEntry entry;
  final DateTime today;
  final ShelfWords words;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = entry.last;
    final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;
    final cover = SeriesCover(
      name: entry.series.name,
      imageUrl: entry.coverUrl,
      width: 96,
    );
    final name = Text(entry.series.name, style: theme.textTheme.headlineSmall);
    final number = last == null
        ? null
        : LastVolumeNumber(number: last, large: true);
    final label = [
      entry.series.name,
      if (last != null) context.l10n.a11ySeriesLast(last),
    ].join(', ');

    return Semantics(
      header: true,
      label: label,
      excludeSemantics: true,
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [cover, const Spacer(), ?number]),
                const SizedBox(height: AppSpacing.md),
                name,
              ],
            )
          : Row(
              children: [
                cover,
                const SizedBox(width: AppSpacing.md),
                Expanded(child: name),
                if (number != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  number,
                ],
              ],
            ),
    );
  }
}

/// « Prochain » : le statut du prochain tome, puis sa source et la date de
/// vérification quand une source a répondu.
class _NextCard extends StatelessWidget {
  const _NextCard({
    required this.entry,
    required this.today,
    required this.words,
  });

  final ShelfEntry entry;
  final DateTime today;
  final ShelfWords words;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = nextVolumeStatus(entry, today);
    final source = words.nextSource(entry, today);
    final icon = switch (status) {
      NextVolumeStatus.complete => Icons.check_circle_outline_rounded,
      NextVolumeStatus.released => Icons.new_releases_outlined,
      NextVolumeStatus.announced => Icons.event_rounded,
      NextVolumeStatus.unknown => Icons.help_outline_rounded,
    };

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHigh,
      child: MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.nextCardTitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      words.nextCard(entry, today),
                      style: theme.textTheme.titleMedium,
                    ),
                    if (source != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        source,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Message plein écran (erreur, série introuvable) avec son action.
class _Message extends StatelessWidget {
  const _Message({
    required this.illustration,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final Widget illustration;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: AnKiEmptyState(
        illustration: illustration,
        title: title,
        message: message,
        primaryLabel: actionLabel,
        onPrimary: onAction,
      ),
    ),
  );
}

/// Squelette : l'en-tête et la carte « Prochain ».
class _LoadingHeader extends StatelessWidget {
  const _LoadingHeader();

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.shelfLoading,
    child: const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xs,
        AppSpacing.gutter,
        0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              SkeletonBox(width: 96, height: 144, radius: AppRadii.md),
              SizedBox(width: AppSpacing.md),
              Expanded(child: SkeletonBox(height: 32)),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 88, radius: AppRadii.lg),
        ],
      ),
    ),
  );
}
