import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Couverture d'une série ou d'un tome, au format d'un livre (2:3).
///
/// Sans image, ou tant qu'elle n'est pas chargée (hors ligne : jamais), les
/// initiales de [name] sur un conteneur tonal : un repli sobre, jamais un
/// trou ni une icône d'erreur. Décorative : le nom est lu à côté.
class SeriesCover extends StatelessWidget {
  const SeriesCover({
    super.key,
    required this.name,
    this.imageUrl,
    this.width = defaultWidth,
  });

  final String name;
  final String? imageUrl;
  final double width;

  /// Largeur dans une ligne de l'étagère.
  static const double defaultWidth = 48;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.all(
      Radius.circular(width >= 96 ? AppRadii.md : AppRadii.xs),
    );
    final initials = AnKiAvatar.initialsOf(name);
    final large = width >= 96;
    // Sans lettre dans le nom (tome sans titre) : un livre plutôt que « ? ».
    final Widget mark = initials.isEmpty
        ? Icon(Icons.menu_book_rounded, color: colorScheme.onSecondaryContainer)
        : Text(
            initials,
            // L'échelle du texte ne grandit pas la vignette : les initiales
            // tiennent dans la couverture, à toute taille.
            textScaler: TextScaler.noScaling,
            style: (large ? textTheme.headlineMedium : textTheme.titleMedium)
                ?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
          );
    final fallback = ColoredBox(
      color: colorScheme.secondaryContainer,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: FittedBox(child: mark),
        ),
      ),
    );
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
