import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:an_ki/features/books/widgets/volume_sheet.dart';
import 'package:flutter/material.dart';

/// Grille des numéros d'une série, de 1 au dernier possédé : possédés pleins
/// (un toucher ouvre le tome), manquants en contour. Chaque case dit à
/// TalkBack son numéro et son état, la couleur n'est jamais le seul indice ;
/// les cases grandissent avec le texte, et la grille réduit ses colonnes.
class VolumeGrid extends StatelessWidget {
  const VolumeGrid({super.key, required this.entry});

  final ShelfEntry entry;

  /// Côté d'une case au texte normal ; 48 dp au moins, cible tactile.
  static const double cellExtent = 56;

  @override
  Widget build(BuildContext context) {
    final last = entry.last ?? 0;
    final byNumber = <int, List<Volume>>{};
    for (final volume in entry.volumes) {
      byNumber.putIfAbsent(volume.number!, () => []).add(volume);
    }
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final extent = cellExtent * scale.clamp(1, 3);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        // Autant de colonnes que de cases d'au moins [extent] : jamais une
        // case sous 48 dp, la grille réduit ses colonnes à 200 %.
        final width = constraints.crossAxisExtent;
        final columns = ((width + AppSpacing.xs) / (extent + AppSpacing.xs))
            .floor()
            .clamp(1, 12);
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.xs,
            crossAxisSpacing: AppSpacing.xs,
          ),
          itemCount: last,
          itemBuilder: (context, index) {
            final number = index + 1;
            final volumes = byNumber[number] ?? const <Volume>[];
            return _Cell(
              number: number,
              editions: volumes.length,
              onTap: volumes.isEmpty
                  ? null
                  : () => unawaited(_open(context, number, volumes)),
            );
          },
        );
      },
    );
  }

  /// Ouvre le tome ; possédé en plusieurs éditions, laisse d'abord choisir.
  static Future<void> _open(
    BuildContext context,
    int number,
    List<Volume> volumes,
  ) async {
    if (volumes.length == 1) {
      return VolumeSheet.show(context, volumes.single.id);
    }
    final picked = await showModalBottomSheet<Volume>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _EditionPicker(number: number, volumes: volumes),
    );
    if (picked != null && context.mounted) {
      await VolumeSheet.show(context, picked.id);
    }
  }
}

/// Les éditions d'un même numéro : titre et ISBN de chacune.
class _EditionPicker extends StatelessWidget {
  const _EditionPicker({required this.number, required this.volumes});

  final int number;
  final List<Volume> volumes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final words = ShelfWords(
      l10n,
      Localizations.localeOf(context).languageCode,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Semantics(
              header: true,
              child: Text(
                l10n.volumeEditionsTitle(number),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final volume in volumes)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              title: Text(words.volumeTitle(volume)),
              subtitle: volume.isbn == null
                  ? null
                  : Text(l10n.volumeIsbn(volume.isbn!)),
              onTap: () => Navigator.pop(context, volume),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.number,
    required this.editions,
    required this.onTap,
  });

  final int number;

  /// Éditions possédées de ce numéro (0 : manquant).
  final int editions;

  /// Null pour un tome manquant.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final owned = onTap != null;
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: owned
          ? colorScheme.onPrimaryContainer
          : colorScheme.onSurfaceVariant,
    );
    final shape = RoundedSuperellipseBorder(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
      side: owned ? BorderSide.none : BorderSide(color: colorScheme.outline),
    );

    return Semantics(
      label: switch (editions) {
        0 => l10n.seriesVolumeMissing(number),
        1 => l10n.seriesVolumeOwned(number),
        _ => l10n.seriesVolumeOwnedEditions(number, editions),
      },
      button: owned,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: owned ? colorScheme.primaryContainer : colorScheme.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                // Plusieurs éditions : une pastille du nombre, en plus du
                // libellé lu par TalkBack.
                child: editions > 1
                    ? Badge(
                        label: Text('$editions'),
                        offset: const Offset(AppSpacing.xs, -AppSpacing.xxs),
                        child: Text('$number', style: style),
                      )
                    : Text('$number', style: style),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
