import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/volume_ranges.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:flutter/material.dart';

/// Ce que « J'ai les tomes 1-12, 15 » va créer, avant « Ajouter » : un petit
/// rayon de dos (possédés pleins, trous en creux, comme sur la page d'une
/// série), puis « 13 tomes » et « Il vous manque 13, 14 ». Une série rejointe
/// compte ses tomes déjà là ([alreadyOwned]) : dos pleins aussi, mais ni
/// comptés ni manquants. Le rayon est décoratif : les lignes disent tout à
/// TalkBack.
class VolumeRangePreview extends StatelessWidget {
  const VolumeRangePreview({
    super.key,
    required this.numbers,
    this.alreadyOwned = const [],
  });

  /// Numéros saisis, triés, sans doublon, non vide.
  final List<int> numbers;

  /// Numéros que la série rejointe possède déjà.
  final List<int> alreadyOwned;

  /// Largeur et hauteur d'un petit dos.
  static const double spineWidth = 16;
  static const double spineHeight = 48;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final already = alreadyOwned.toSet();
    final owned = {...numbers, ...already};
    final last = owned.reduce((a, b) => a > b ? a : b);
    final added = numbers.where((n) => !already.contains(n)).length;
    final holes = ShelfWords(
      l10n,
      Localizations.localeOf(context).languageCode,
    ).holesLine(holesIn(owned.toList()));
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            height: spineHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: last,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xxs),
              itemBuilder: (context, index) => _MiniSpine(
                number: index + 1,
                owned: owned.contains(index + 1),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          added == 0
              ? l10n.addSeriesPreviewAllOwned
              : l10n.addSeriesPreviewCount(added),
          style: theme.textTheme.labelLarge,
        ),
        if (holes != null) Text(holes, style: muted),
      ],
    );
  }
}

/// Un petit dos : plein (un ton sur deux) quand le tome est là, en creux
/// sinon.
class _MiniSpine extends StatelessWidget {
  const _MiniSpine({required this.number, required this.owned});

  final int number;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final colors = context.ankiColors;
    final outline = Theme.of(context).colorScheme.outline;
    return SizedBox(
      width: VolumeRangePreview.spineWidth,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: owned
              ? (number.isEven ? colors.spine : colors.spineAlt)
              : null,
          shape: RoundedSuperellipseBorder(
            borderRadius: const BorderRadius.all(Radius.circular(AppRadii.xs)),
            side: BorderSide(color: owned ? colors.spineEdge : outline),
          ),
        ),
      ),
    );
  }
}
