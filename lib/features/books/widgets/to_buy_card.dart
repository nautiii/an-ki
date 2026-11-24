import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/shelf_agenda.dart';
import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:an_ki/features/books/widgets/shelf_display.dart';
import 'package:flutter/material.dart';

/// « Paru · pas encore chez vous » : en tête de l'étagère, les tomes sortis
/// que l'on n'a pas, chacun avec « Acheté » (un toucher, « Annuler »
/// ensuite). La seule carte lotus de l'écran : c'est ce qui demande d'agir.
/// Au-delà de [shown] tomes, « Voir les N autres » déplie le reste : la liste
/// des séries ne disparaît pas sous la carte.
class ToBuyCard extends StatefulWidget {
  const ToBuyCard({
    super.key,
    required this.purchases,
    required this.today,
    required this.onBought,
    required this.onOpen,
  });

  final List<ShelfPurchase> purchases;
  final DateTime today;

  /// « Acheté » sur [ShelfPurchase].
  final ValueChanged<ShelfPurchase> onBought;

  /// Ouvre la série du tome.
  final ValueChanged<ShelfPurchase> onOpen;

  /// Tomes montrés avant « Voir les N autres ».
  static const int shown = 3;

  @override
  State<ToBuyCard> createState() => _ToBuyCardState();
}

class _ToBuyCardState extends State<ToBuyCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final on = colorScheme.onSecondaryContainer;
    final purchases = widget.purchases;
    final hidden = _expanded ? 0 : purchases.length - ToBuyCard.shown;
    final visible = hidden > 0 ? purchases.take(ToBuyCard.shown) : purchases;
    return Material(
      color: colorScheme.secondaryContainer,
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Semantics(
                header: true,
                child: Row(
                  children: [
                    Icon(Icons.new_releases_rounded, size: 20, color: on),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        context.l10n.shelfToBuyTitle,
                        style: textTheme.labelLarge?.copyWith(color: on),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            for (final purchase in visible)
              _ToBuyRow(
                key: ValueKey(purchase.entry.series.id),
                purchase: purchase,
                today: widget.today,
                onBought: () => widget.onBought(purchase),
                onOpen: () => widget.onOpen(purchase),
              ),
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = true),
                    child: Text(context.l10n.shelfToBuyMore(hidden)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un tome paru : couverture, « Blacksad · tome 7 », « Paru le … », et
/// « Acheté ». Toucher la ligne ouvre la série.
class _ToBuyRow extends StatelessWidget {
  const _ToBuyRow({
    super.key,
    required this.purchase,
    required this.today,
    required this.onBought,
    required this.onOpen,
  });

  final ShelfPurchase purchase;
  final DateTime today;
  final VoidCallback onBought;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final on = colorScheme.onSecondaryContainer;
    final words = ShelfWords(
      l10n,
      Localizations.localeOf(context).languageCode,
    );
    final name = purchase.entry.series.name;
    final title = l10n.shelfVolumeOf(name, purchase.number);
    final line = words.toBuyLine(purchase, today);
    final cover = SeriesCover(
      name: name,
      imageUrl: purchase.entry.coverUrl,
      width: 40,
      onLotus: true,
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleMedium?.copyWith(color: on)),
        Text(line, style: textTheme.bodyMedium?.copyWith(color: on)),
      ],
    );
    // La couverture et le texte ouvrent la série ; « Acheté » est à part.
    final identity = Semantics(
      button: true,
      label: '$title, $line',
      excludeSemantics: true,
      onTap: onOpen,
      child: InkWell(
        onTap: onOpen,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Row(
            children: [
              cover,
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: text),
            ],
          ),
        ),
      ),
    );
    // Tonal, mais sur le lotus : la pastille prend la toile pour se voir.
    final button = FilledButton.tonalIcon(
      onPressed: onBought,
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
      ),
      icon: const Icon(Icons.check_rounded),
      label: Semantics(
        label: l10n.a11yShelfBought(name, purchase.number),
        excludeSemantics: true,
        child: Text(l10n.shelfBought),
      ),
    );
    final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Écran étroit ou grand texte : le bouton passe sous le texte.
          // 296 : un téléphone de 393 dp garde le bouton à droite, un de
          // 360 dp le passe dessous.
          if (stacked || constraints.maxWidth < 296) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                Align(alignment: AlignmentDirectional.centerEnd, child: button),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: AppSpacing.xs),
              button,
            ],
          );
        },
      ),
    );
  }
}
