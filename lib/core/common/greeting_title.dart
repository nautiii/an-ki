import 'dart:math' as math;

import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Titre de la barre d'app des onglets : « Bonjour, Camille » sur une ligne
/// quand elle tient ; sinon « Bonjour » au-dessus du prénom, qui garde toute
/// la largeur (prénom long, écran étroit, grand texte) au lieu de
/// « Bonjour, Ma… ».
class GreetingTitle extends StatelessWidget {
  const GreetingTitle({
    super.key,
    required this.greeting,
    required this.name,
    required this.oneLine,
  });

  /// Salutation déjà traduite (« Bonjour », « Bonsoir »).
  final String greeting;

  /// Prénom, null sans nom (invité, profil pas encore chargé).
  final String? name;

  /// Salutation et prénom sur une ligne, ou la salutation seule sans prénom.
  final String oneLine;

  /// Plafond du texte d'un titre d'[AppBar] (Material, repris par Flutter) :
  /// au-delà, le titre ne grandit plus, pour garder la hiérarchie.
  static const double _maxTitleTextScale = 1.34;

  /// Hauteur de la barre : les deux lignes y tiennent à toute taille de
  /// texte ; à la taille normale, c'est celle d'une barre standard.
  static double toolbarHeight(BuildContext context) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: _maxTitleTextScale);
    double lineHeight(TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: ' ', style: style),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final lines =
        lineHeight(_greetingStyle(theme)) +
        lineHeight(
          theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge,
        );
    return math.max(kToolbarHeight, lines + 2 * AppSpacing.xxs);
  }

  static TextStyle? _greetingStyle(ThemeData theme) => theme
      .textTheme
      .bodyMedium
      ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

  @override
  Widget build(BuildContext context) {
    final name = this.name;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (name == null || _fitsOnOneLine(context, constraints.maxWidth)) {
          return Text(oneLine);
        }
        // Lue d'un trait par TalkBack, comme la ligne unique.
        return Semantics(
          label: oneLine,
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: _greetingStyle(Theme.of(context))),
              Text(name),
            ],
          ),
        );
      },
    );
  }

  /// La ligne unique tient dans [maxWidth], au style du titre de la barre.
  bool _fitsOnOneLine(BuildContext context, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: oneLine, style: DefaultTextStyle.of(context).style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    final fits = !painter.didExceedMaxLines;
    painter.dispose();
    return fits;
  }
}
