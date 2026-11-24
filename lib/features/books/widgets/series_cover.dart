import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Couverture d'une série ou d'un tome, au format d'un livre (2:3).
///
/// Sans image, ou tant qu'elle n'est pas chargée (hors ligne : jamais), une
/// « jaquette » lotus : à partir de 72 dp le nom composé en haut, en dessous
/// les initiales, avec la pliure côté dos et le bandeau du bas dès 48 dp. Un
/// repli qui reste un livre, jamais un trou ni une icône d'erreur.
/// Décorative : le nom est lu à côté.
class SeriesCover extends StatelessWidget {
  const SeriesCover({
    super.key,
    required this.name,
    this.imageUrl,
    this.width = defaultWidth,
    this.onLotus = false,
  });

  final String name;
  final String? imageUrl;
  final double width;

  /// Posée sur un conteneur lotus (`secondaryContainer`) : le repli prend la
  /// toile et l'encre framboise, sinon il s'y fondrait.
  final bool onLotus;

  /// Largeur dans une ligne de l'étagère.
  static const double defaultWidth = 56;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = onLotus
        ? colorScheme.surface
        : colorScheme.secondaryContainer;
    final ink = onLotus
        ? colorScheme.primary
        : colorScheme.onSecondaryContainer;
    final radius = BorderRadius.all(
      Radius.circular(
        width >= 96
            ? AppRadii.md
            : width >= 48
            ? AppRadii.sm
            : AppRadii.xs,
      ),
    );
    final fallback = width >= 72
        ? _Jacket(name: name, width: width, background: background, ink: ink)
        : _Initials(name: name, width: width, background: background, ink: ink);
    final url = imageUrl;

    return ExcludeSemantics(
      child: ClipRSuperellipse(
        borderRadius: radius,
        child: SizedBox(
          width: width,
          height: width * 1.5,
          child: url == null || url.isEmpty
              ? fallback
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  // Le repli reste dessous tant que l'image n'est pas là.
                  frameBuilder: (context, child, frame, synchronous) =>
                      frame == null && !synchronous ? fallback : child,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

/// Pliure côté dos et bandeau du bas : ce qui fait d'un aplat un livre.
class _BookMarks extends StatelessWidget {
  const _BookMarks({required this.ink, required this.fold, required this.band});

  final Color ink;
  final double fold;
  final double band;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: fold,
          child: ColoredBox(color: ink.withValues(alpha: 0.08)),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: band,
          child: ColoredBox(color: ink.withValues(alpha: 0.75)),
        ),
      ],
    );
  }
}

/// Les initiales au centre (un livre sans titre : une icône de livre).
class _Initials extends StatelessWidget {
  const _Initials({
    required this.name,
    required this.width,
    required this.background,
    required this.ink,
  });

  final String name;
  final double width;
  final Color background;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final initials = AnKiAvatar.initialsOf(name);
    final textTheme = Theme.of(context).textTheme;
    final book = width >= 48;
    final mark = Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: FittedBox(
          child: initials.isEmpty
              ? Icon(Icons.menu_book_rounded, color: ink)
              : Text(
                  initials,
                  // L'échelle du texte ne grandit pas la vignette : les
                  // initiales tiennent dans la couverture, à toute taille.
                  textScaler: TextScaler.noScaling,
                  style: (book ? textTheme.titleLarge : textTheme.titleMedium)
                      ?.copyWith(color: ink, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
    return ColoredBox(
      color: background,
      child: book
          ? Stack(
              fit: StackFit.expand,
              children: [
                _BookMarks(
                  ink: ink,
                  fold: AppSpacing.xxs,
                  band: AppSpacing.xxs,
                ),
                mark,
              ],
            )
          : mark,
    );
  }
}

/// Grande couverture sans image : le nom composé comme un vrai titre.
class _Jacket extends StatelessWidget {
  const _Jacket({
    required this.name,
    required this.width,
    required this.background,
    required this.ink,
  });

  final String name;
  final double width;
  final Color background;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final big = width >= 136;
    final pad = big ? AppSpacing.md : AppSpacing.xs;
    final band = big ? AppSpacing.xs : AppSpacing.xxs;
    final fold = big ? AppSpacing.xs : AppSpacing.xxs;
    return ColoredBox(
      color: background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _BookMarks(ink: ink, fold: fold, band: band),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              pad + fold / 2,
              pad,
              pad,
              pad + band,
            ),
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: Text(
                name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: (big ? textTheme.titleLarge : textTheme.titleSmall)
                    ?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
