import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/shelf_view.dart';
import 'package:an_ki/features/books/widgets/classify_sheet.dart';
import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:an_ki/features/books/widgets/shelf_undo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Feuille d'un tome : couverture flottante, série et numéro, titre, auteurs,
/// date de parution, ISBN et état de la recherche ; puis ses actions en liste
/// (le classer, ajouter les tomes d'avant, le retirer avec « Annuler »). Un
/// tome à classer a une seule action pleine, « Classer ». Suit l'étagère : un
/// classement se voit aussitôt, un tome retiré ferme la feuille.
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
    return _VolumeDetails(
      volume: volume,
      seriesName: seriesName,
      missingPrevious: ref.watch(missingPreviousProvider(volumeId)),
    );
  }
}

class _VolumeDetails extends StatelessWidget {
  const _VolumeDetails({
    required this.volume,
    required this.seriesName,
    required this.missingPrevious,
  });

  final Volume volume;

  /// Nom de la série du tome ; null s'il est à classer.
  final String? seriesName;

  /// Numéros d'avant que sa série n'a pas : « J'ai aussi les tomes 1 à 4 ».
  final List<int> missingPrevious;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final words = ShelfWords(
      l10n,
      Localizations.localeOf(context).languageCode,
    );
    final title = words.volumeTitle(volume);
    final number = volume.number;
    final seriesName = this.seriesName;
    final classified = seriesName != null && number != null;
    final published = switch (volume.publishedDate) {
      final raw? when raw.trim().isNotEmpty => words.published(raw),
      _ => null,
    };
    final isbn = volume.isbn;

    return SingleChildScrollView(
      // `useSafeArea` laisse le bas à la feuille : la barre système (trois
      // boutons) ne cache pas « Retirer de la collection ».
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            volume: volume,
            coverName: seriesName ?? volume.title,
            title: title,
            overline: classified
                ? l10n.volumeInSeries(seriesName, number)
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          if (published != null)
            _Fact(icon: Icons.event_rounded, text: published),
          // Un tome sans titre s'appelle déjà « ISBN … » : pas deux fois.
          if (isbn != null && title != l10n.volumeIsbn(isbn))
            _Fact(icon: Icons.tag_rounded, text: l10n.volumeIsbn(isbn)),
          switch (volume.lookup) {
            LookupState.pending => _Status(
              icon: Icons.hourglass_top_rounded,
              text: l10n.volumePending,
              cloud: true,
            ),
            LookupState.notFound => _Status(
              icon: Icons.help_outline_rounded,
              text: l10n.volumeNotFound,
              cloud: false,
            ),
            LookupState.found => const SizedBox.shrink(),
          },
          const SizedBox(height: AppSpacing.md),
          if (classified) ...[
            const Divider(height: 1),
            _Action(
              icon: Icons.swap_horiz_rounded,
              label: l10n.volumeClassify,
              onTap: () => _classify(context),
            ),
            if (missingPrevious.isNotEmpty)
              _Action(
                icon: Icons.library_add_rounded,
                label: previousVolumesLabel(l10n, missingPrevious),
                onTap: () {
                  // La snackbar « Annuler » s'affiche sous la feuille, qui se
                  // ferme : la série et ses trous suivent derrière.
                  addPreviousWithUndo(context, volume.id);
                  Navigator.pop(context);
                },
              ),
          ] else ...[
            // À classer : la seule action pleine de la feuille.
            FilledButton.icon(
              onPressed: () => _classify(context),
              icon: const Icon(Icons.shelves),
              label: Text(l10n.volumeSort),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          _Action(
            icon: Icons.delete_outline_rounded,
            label: l10n.volumeRemove,
            destructive: true,
            onTap: () => removeVolumeWithUndo(context, volume, title: title),
          ),
        ],
      ),
    );
  }

  void _classify(BuildContext context) =>
      unawaited(ClassifySheet.show(context, volume));
}

/// La couverture, flottante comme sur la page d'une série, à côté de la
/// série et du numéro ([overline]), du titre et des auteurs.
class _Header extends StatelessWidget {
  const _Header({
    required this.volume,
    required this.coverName,
    required this.title,
    required this.overline,
  });

  final Volume volume;

  /// Le nom que porte une couverture sans image : celui de la série.
  final String coverName;
  final String title;
  final String? overline;

  /// Largeur de la couverture.
  static const double coverWidth = 88;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.ankiColors;
    final overline = this.overline;
    final cover = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
          side: BorderSide(color: colors.glassBorder),
        ),
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.sm)),
          ),
          shadows: colors.floatingShadow,
        ),
        child: SeriesCover(
          name: coverName,
          imageUrl: volume.imageUrl,
          width: coverWidth,
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: cover),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // La série et le titre, lus d'un trait comme titre : naviguer
              // par titres dit de quelle série est le tome.
              MergeSemantics(
                child: Semantics(
                  header: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (overline != null)
                        Text(
                          overline,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (volume.authors.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  volume.authors.join(', '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Une information du tome : une icône discrète et son texte.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 20, color: muted)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// L'état de la recherche, en pastille : nuage quand des infos sont encore
/// à venir, neutre quand aucun catalogue ne connaît le livre.
class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.text, required this.cloud});

  final IconData icon;
  final String text;
  final bool cloud;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = cloud
        ? colorScheme.tertiaryContainer
        : colorScheme.surfaceContainerHighest;
    final ink = cloud
        ? colorScheme.onTertiaryContainer
        : colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: background,
            shape: const StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(child: Icon(icon, size: 16, color: ink)),
                const SizedBox(width: AppSpacing.xxs),
                Flexible(
                  child: Text(
                    text,
                    style: theme.textTheme.labelLarge?.copyWith(color: ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Une action du tome, en ligne de liste ; [destructive] : en rouge erreur.
class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = destructive ? colorScheme.error : colorScheme.primary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: destructive ? TextStyle(color: color) : null),
      onTap: onTap,
    );
  }
}
