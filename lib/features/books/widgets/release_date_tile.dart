import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// La tuile date : le jour et le jour de semaine, ou le mois seul. Nuage :
/// le temps à venir, jamais une action.
class ReleaseDateTile extends StatelessWidget {
  const ReleaseDateTile({super.key, required this.date});

  /// Largeur et hauteur minimales de la tuile.
  static const double size = 56;

  final ReleaseDate date;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    final on = colorScheme.onTertiaryContainer;
    final day = date.day;
    final value = DateTime(date.year, date.month, day ?? 1);
    final Widget content = day == null
        ? Text(
            DateFormat.MMM(locale).format(value),
            style: textTheme.titleSmall?.copyWith(
              color: on,
              fontWeight: FontWeight.w700,
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$day',
                style: textTheme.titleLarge?.copyWith(
                  color: on,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                DateFormat.E(locale).format(value),
                style: textTheme.labelMedium?.copyWith(color: on),
              ),
            ],
          );
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: size, minHeight: size),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colorScheme.tertiaryContainer,
            shape: const RoundedSuperellipseBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Center(widthFactor: 1, heightFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}
