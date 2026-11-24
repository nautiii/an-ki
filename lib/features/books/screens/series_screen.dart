import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/features/books/widgets/glass_circle.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/providers/release_check.dart';
import 'package:an_ki/features/books/providers/shelf_offline.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/providers/shelf_view.dart';
import 'package:an_ki/features/books/widgets/next_volume_card.dart';
import 'package:an_ki/features/books/widgets/offline_banner.dart';
import 'package:an_ki/features/books/widgets/pending_completer.dart';
import 'package:an_ki/features/books/widgets/series_actions.dart';
import 'package:an_ki/features/books/widgets/series_header.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:an_ki/features/books/widgets/shelf_undo.dart';
import 'package:an_ki/features/books/widgets/spine_shelf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Page d'une série : la couverture floutée en fond, la couverture nette, le
/// nom et le dernier tome ; le prochain tome ; « Vos tomes », un rayon de
/// dos ; ce qui manque, avec « Je les ai ». Son menu renomme, fusionne,
/// marque terminée ou supprime la série.
///
/// Un id inconnu (série supprimée, fusionnée, d'un autre compte) a son propre
/// message ; une série qui disparaît pendant qu'on la regarde ferme la page.
/// Tirer vers le bas vérifie le prochain tome à la BnF (`ReleaseCheck`).
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
    // « Tirer pour actualiser » : un échec se dit en bas, la page reste.
    ref.listen(releaseCheckProvider, (_, next) {
      if (next is! AsyncError) return;
      final l10n = context.l10n;
      final message = switch (next.error) {
        BookFailure.network => l10n.errorNetwork,
        BookFailure() => l10n.nextRefreshError,
        _ => l10n.shelfWriteError,
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });

    if (entry case AsyncValue(hasError: false, hasValue: true, :final value)
        when value != null) {
      return PendingCompleter(
        child: _SeriesDetails(entry: value, offline: offline),
      );
    }

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
      AsyncValue(hasValue: true) => _Message(
        illustration: Image.asset(AppAssets.moon),
        title: l10n.seriesMissingTitle,
        message: l10n.seriesMissingMessage,
        actionLabel: l10n.seriesBackToShelf,
        onAction: () => context.go(AppRoutes.books),
      ),
      _ => const _LoadingHeader(),
    };

    return PendingCompleter(
      child: Scaffold(
        appBar: AppBar(),
        body: SafeArea(top: false, child: body),
      ),
    );
  }
}

/// La série lue : l'en-tête sous une barre transparente (retour et menu sur
/// des ronds de verre), puis le prochain tome, le rayon et les trous.
class _SeriesDetails extends ConsumerStatefulWidget {
  const _SeriesDetails({required this.entry, required this.offline});

  final ShelfEntry entry;
  final bool offline;

  @override
  ConsumerState<_SeriesDetails> createState() => _SeriesDetailsState();
}

class _SeriesDetailsState extends ConsumerState<_SeriesDetails> {
  final _shelf = GlobalKey<SpineShelfState>();

  void _add(List<int> numbers) =>
      addNumbersWithUndo(context, widget.entry.series.id, numbers);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final today = ref.watch(todayProvider);
    final entry = widget.entry;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        // Le rond de verre à 8 dp du bord, comme le menu en face.
        leadingWidth: AppSpacing.xxl + AppSpacing.xs,
        leading: canPop
            ? const Align(
                alignment: AlignmentDirectional.centerEnd,
                child: GlassCircle(child: BackButton()),
              )
            : null,
        actions: [
          GlassCircle(child: SeriesMenu(entry: entry)),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        edgeOffset: topInset,
        onRefresh: () => ref
            .read(releaseCheckProvider.notifier)
            .checkSeries(entry.series.id),
        child: CustomScrollView(
          // Tirable même quand la page tient dans l'écran.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SeriesHeader(entry: entry, topInset: topInset),
            ),
            SliverSafeArea(
              top: false,
              sliver: SliverMainAxisGroup(
                slivers: [
                  if (widget.offline)
                    const SliverToBoxAdapter(child: OfflineBanner()),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: NextVolumeCard(
                        entry: entry,
                        today: today,
                        onBought: (number) => _add([number]),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.xl,
                      AppSpacing.gutter,
                      AppSpacing.sm,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.seriesVolumesTitle,
                          style: textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: entry.last == null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.gutter,
                            ),
                            child: Text(
                              l10n.seriesNoVolume,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : SpineShelf(
                            key: _shelf,
                            entry: entry,
                            today: today,
                            onAdd: (number) => _add([number]),
                          ),
                  ),
                  if (entry.holes.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        AppSpacing.md,
                        AppSpacing.gutter,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _Holes(
                          entry: entry,
                          onShow: () =>
                              _shelf.currentState?.show(entry.holes.first),
                          onHave: () => _add(entry.holes),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        ),
      ),
    );
  }
}

/// « Il vous manque 13, 14 » (un toucher fait défiler le rayon jusqu'au
/// premier) et « Je les ai ».
class _Holes extends StatelessWidget {
  const _Holes({
    required this.entry,
    required this.onShow,
    required this.onHave,
  });

  final ShelfEntry entry;
  final VoidCallback onShow;
  final VoidCallback onHave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final words = ShelfWords(
      l10n,
      Localizations.localeOf(context).languageCode,
    );
    final count = entry.holes.length;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        TextButton(
          onPressed: onShow,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            textStyle: Theme.of(context).textTheme.bodyLarge,
          ),
          child: Semantics(
            onTapHint: l10n.a11yHolesShowHint,
            child: Text(words.holesLine(entry.holes)!),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: onHave,
          icon: const Icon(Icons.check_rounded),
          label: Semantics(
            label: l10n.a11ySeriesHaveHoles(count),
            excludeSemantics: true,
            child: Text(l10n.seriesHaveHoles(count)),
          ),
        ),
      ],
    );
  }
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

/// Squelette : la couverture centrée, le nom, la carte du prochain tome.
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
          SkeletonBox(
            width: SeriesHeader.coverWidth,
            height: SeriesHeader.coverWidth * 1.5,
            radius: AppRadii.md,
          ),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(width: 200, height: 32),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 120, radius: AppRadii.lg),
        ],
      ),
    ),
  );
}
