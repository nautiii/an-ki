import 'dart:math' as math;

import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/greeting_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Barre d'app de l'accueil, épinglée : salutation de l'heure et prénom, puis
/// recherche, ajout et réglages (l'avatar).
class HomeAppBar extends ConsumerWidget {
  const HomeAppBar({super.key, required this.canSearch});

  /// Affiche la recherche : rien à chercher dans un carnet vide.
  final bool canSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final period = ref.watch(greetingProvider).name;
    // Sans nom (invité, profil pas encore chargé) : la salutation seule.
    final name = ref.watch(greetingNameProvider);
    final greeting = l10n.greeting(period);

    return SliverAppBar(
      pinned: true,
      centerTitle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      titleSpacing: AppSpacing.gutter,
      toolbarHeight: _Greeting.toolbarHeight(context),
      title: _Greeting(
        greeting: greeting,
        name: name,
        oneLine: name == null ? greeting : l10n.greetingName(period, name),
      ),
      actions: [
        if (canSearch)
          IconButton(
            onPressed: () => context.push(AppRoutes.search),
            tooltip: l10n.searchTooltip,
            icon: const Icon(Icons.search_rounded),
          ),
        IconButton.filledTonal(
          onPressed: () => BirthdayFormSheet.show(context),
          tooltip: l10n.addBirthday,
          icon: const Icon(Icons.add_rounded),
        ),
        IconButton(
          onPressed: () => context.push(AppRoutes.settings),
          tooltip: l10n.settings,
          icon: AnKiAvatar(name: name ?? '', radius: 16),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}

/// « Bonjour, Camille » sur une ligne quand elle tient ; sinon « Bonjour »
/// au-dessus du prénom, qui garde toute la largeur (prénom long, écran
/// étroit, grand texte) au lieu de « Bonjour, Ma… ».
class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.greeting,
    required this.name,
    required this.oneLine,
  });

  final String greeting;
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
