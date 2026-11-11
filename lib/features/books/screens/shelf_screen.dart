import 'dart:async';

import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/providers/legacy_import.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:an_ki/features/books/providers/shelf_offline.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/providers/shelf_view.dart';
import 'package:an_ki/features/books/widgets/offline_banner.dart';
import 'package:an_ki/features/books/widgets/series_tile.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/features/books/widgets/pending_completer.dart';
import 'package:an_ki/features/books/widgets/add_series_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// L'étagère, racine de l'onglet Livres : recherche, « À classer (n) », puis
/// les séries de A à Z (façon Contacts : prévisible pour retrouver une série
/// en rayon).
class ShelfScreen extends ConsumerWidget {
  const ShelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Les anciens livres passent dans l'étagère à l'ouverture de Livres, une
    // fois par session ; hors ligne, à l'ouverture suivante.
    ref.watch(legacyImportProvider);
    // Les écritures sont optimistes (feuilles fermées, page quittée) :
    // l'onglet, toujours monté, annonce un échec tardif.
    ref.listen(shelfEditorProvider, (_, next) {
      if (next is AsyncError) {
        // Il contredit la snackbar affichée : il la remplace (patterns.md).
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.l10n.shelfWriteError)));
      }
    });
    final shelf = ref.watch(shelfProvider);
    final offline = ref.watch(shelfOfflineProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    // Un message plein écran, centré au-dessus de la barre flottante.
    Widget message(Widget child) => SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom + AppSpacing.md),
        child: Center(child: child),
      ),
    );

    final List<Widget> content = switch (shelf) {
      AsyncValue(hasError: true) => [
        message(
          _ShelfError(
            error: shelf.error,
            onRetry: () => ref
              ..invalidate(bookSeriesProvider)
              ..invalidate(bookVolumesProvider),
          ),
        ),
      ],
      AsyncValue(hasValue: true, value: final value?)
          when value.entries.isEmpty && value.unclassified.isEmpty =>
        [message(const _FirstRun())],
      AsyncValue(hasValue: true, value: final value?) => [
        _ShelfContent(shelf: value),
        // Place de la barre de navigation flottante, puis une respiration.
        SliverToBoxAdapter(child: SizedBox(height: bottom + AppSpacing.md)),
      ],
      _ => [const _ShelfSkeleton()],
    };

    // Les tomes scannés hors ligne se complètent à l'ouverture de Livres.
    return PendingCompleter(
      checkReleases: true,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            const _ShelfAppBar(),
            // Hors ligne avec une étagère lue du cache ; une erreur se dit seule.
            if (offline && !shelf.hasError)
              const SliverToBoxAdapter(child: OfflineBanner()),
            ...content,
          ],
        ),
      ),
    );
  }
}

/// Barre épinglée, comme l'accueil : le titre, le scan, les réglages.
class _ShelfAppBar extends ConsumerWidget {
  const _ShelfAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final name = ref.watch(greetingNameProvider);
    return SliverAppBar(
      pinned: true,
      centerTitle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      titleSpacing: AppSpacing.gutter,
      title: Text(l10n.moduleBooks),
      actions: [
        IconButton(
          onPressed: () => unawaited(addSeriesByHand(context)),
          tooltip: l10n.addSeriesByHand,
          icon: const Icon(Icons.library_add_rounded),
        ),
        IconButton.filledTonal(
          onPressed: () => unawaited(context.push(AppRoutes.booksScan)),
          tooltip: l10n.scanBook,
          icon: const Icon(Icons.qr_code_scanner_rounded),
        ),
        IconButton(
          onPressed: () => unawaited(context.push(AppRoutes.settings)),
          tooltip: l10n.settings,
          icon: AnKiAvatar(name: name ?? '', radius: 16),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}

/// Recherche, carte « À classer », puis les séries trouvées.
class _ShelfContent extends ConsumerWidget {
  const _ShelfContent({required this.shelf});

  final Shelf shelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final query = ref.watch(shelfSearchProvider).trim();
    final series = ref.watch(shelfSeriesListProvider).value ?? const [];
    final unclassified = shelf.unclassified.length;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xs,
        AppSpacing.gutter,
        0,
      ),
      sliver: SliverList.list(
        children: [
          if (shelf.entries.isNotEmpty) ...[
            const _ShelfSearchField(),
            const SizedBox(height: AppSpacing.md),
          ],
          if (unclassified > 0 && query.isEmpty) ...[
            _InboxCard(count: unclassified),
            const SizedBox(height: AppSpacing.md),
          ],
          if (series.isEmpty && query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                l10n.shelfNoResults(query),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final entry in series) ...[
            SeriesTile(
              key: ValueKey(entry.series.id),
              entry: entry,
              onTap: () =>
                  unawaited(context.push(AppRoutes.series(entry.series.id))),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// Champ de recherche de l'étagère, filtre à chaque lettre.
class _ShelfSearchField extends ConsumerStatefulWidget {
  const _ShelfSearchField();

  @override
  ConsumerState<_ShelfSearchField> createState() => _ShelfSearchFieldState();
}

class _ShelfSearchFieldState extends ConsumerState<_ShelfSearchField> {
  late final _controller = TextEditingController(
    text: ref.read(shelfSearchProvider),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(shelfSearchProvider.notifier).update('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = ref.watch(shelfSearchProvider);
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onChanged: ref.read(shelfSearchProvider.notifier).update,
      decoration: InputDecoration(
        hintText: l10n.shelfSearchHint,
        prefixIcon: const Icon(Icons.search_rounded),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.xl)),
          borderSide: BorderSide.none,
        ),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                onPressed: _clear,
                tooltip: l10n.clearSearch,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }
}

/// « À classer (n) » : les tomes sans série ni numéro, ouverts d'un toucher.
class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.secondaryContainer,
      child: ListTile(
        onTap: () => unawaited(context.push(AppRoutes.booksInbox)),
        leading: Icon(
          Icons.inbox_rounded,
          color: colorScheme.onSecondaryContainer,
        ),
        title: Text(
          l10n.shelfInbox(count),
          style: TextStyle(color: colorScheme.onSecondaryContainer),
        ),
        subtitle: Text(
          l10n.shelfInboxHint(count),
          style: TextStyle(color: colorScheme.onSecondaryContainer),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Premier lancement : la lune, « Scanner un livre » et « Ajouter une
/// série à la main ».
class _FirstRun extends StatelessWidget {
  const _FirstRun();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnKiEmptyState(
      illustration: Image.asset(AppAssets.moon),
      title: l10n.shelfEmptyTitle,
      message: l10n.shelfEmptyMessage,
      primaryLabel: l10n.scanBook,
      primaryIcon: Icons.qr_code_scanner_rounded,
      onPrimary: () => unawaited(context.push(AppRoutes.booksScan)),
      secondaryLabel: l10n.addSeriesByHand,
      onSecondary: () => unawaited(addSeriesByHand(context)),
    );
  }
}

/// Ouvre « Ajouter une série », puis la série ajoutée.
Future<void> addSeriesByHand(BuildContext context) async {
  final id = await AddSeriesSheet.show(context);
  if (id == null || !context.mounted) return;
  await context.push(AppRoutes.series(id));
}

/// L'étagère n'a pas pu être lue : quoi, comment, et « Réessayer ».
class _ShelfError extends StatelessWidget {
  const _ShelfError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnKiEmptyState(
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
      primaryIcon: Icons.refresh_rounded,
      onPrimary: onRetry,
    );
  }
}

/// Squelette : la recherche et quatre lignes de séries.
class _ShelfSkeleton extends StatelessWidget {
  const _ShelfSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xs,
        AppSpacing.gutter,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: Semantics(
          label: context.l10n.shelfLoading,
          child: Column(
            children: [
              const SkeletonBox(height: 56, radius: AppRadii.xl),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < 4; i++) ...[
                const SkeletonBox(height: 96, radius: AppRadii.lg),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
