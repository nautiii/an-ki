import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Un galet `surfaceContainerLow` qui regroupe des lignes, séparées par des
/// filets alignés sur leur texte ([dividerIndent]) ; en grand texte, les
/// lignes s'empilent et le filet part du bord.
class ShelfGroup extends StatelessWidget {
  const ShelfGroup({
    super.key,
    required this.children,
    required this.dividerIndent,
  });

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;
    return Material(
      color: colorScheme.surfaceContainerLow,
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: largeText ? AppSpacing.md : dividerIndent,
                endIndent: AppSpacing.md,
                color: colorScheme.outlineVariant,
              ),
            child,
          ],
        ],
      ),
    );
  }
}

/// Une ligne d'un galet construit à la demande (une longue liste dans un
/// `SliverList.builder`) : même fond et même filet que [ShelfGroup], les
/// coins arrondis seulement en haut de la première et en bas de la dernière.
class ShelfGroupItem extends StatelessWidget {
  const ShelfGroupItem({
    super.key,
    required this.index,
    required this.count,
    required this.dividerIndent,
    required this.child,
  });

  /// Rang de la ligne, de 0 à [count] − 1.
  final int index;
  final int count;
  final double dividerIndent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;
    const round = Radius.circular(AppRadii.lg);
    final first = index == 0;
    final last = index == count - 1;
    return Material(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(
          top: first ? round : Radius.zero,
          bottom: last ? round : Radius.zero,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!first)
            Divider(
              height: 1,
              thickness: 1,
              indent: largeText ? AppSpacing.md : dividerIndent,
              endIndent: AppSpacing.md,
              color: colorScheme.outlineVariant,
            ),
          child,
        ],
      ),
    );
  }
}

/// Libellé d'une section de l'étagère : un titre (« Prochaines sorties »)
/// ou, discret, un repère (« 6 séries, de A à Z »). Lu comme un en-tête.
class ShelfSectionLabel extends StatelessWidget {
  const ShelfSectionLabel(this.text, {super.key, this.title = false});

  final String text;

  /// Titre de section (`titleSmall`) ; sinon un libellé discret.
  final bool title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.xxs),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: title
              ? theme.textTheme.titleSmall
              : theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
      ),
    );
  }
}
