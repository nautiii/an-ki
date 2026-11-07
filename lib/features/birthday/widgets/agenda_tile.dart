import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/common/orbit_countdown.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/domain/birthday_search.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Ligne d'agenda : qui, quand, quel âge. L'anneau de l'avatar porte les
/// couleurs des catégories de la personne.
///
/// Toucher ouvre la page de la personne. Glisser vers la gauche, ou l'action
/// « Supprimer » des lecteurs d'écran, supprime avec « Annuler ».
class AgendaTile extends ConsumerWidget {
  const AgendaTile({super.key, required this.birthday, this.highlight});

  final Birthday birthday;

  /// Lettres du nom trouvées par la recherche (`BirthdayNameMatch`),
  /// surlignées ; null hors recherche.
  final MatchRange? highlight;

  static const _radius = BorderRadius.all(Radius.circular(AppRadii.lg));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRSuperellipse(
      borderRadius: _radius,
      child: Dismissible(
        key: Key(birthday.id),
        // La droite reste libre pour une action positive (« Souhaiter »).
        direction: DismissDirection.endToStart,
        // Le seuil franchi se sent : lâcher supprime. La suppression ne
        // vibre pas une seconde fois.
        onUpdate: (details) {
          if (details.reached && !details.previousReached) {
            HapticFeedback.mediumImpact();
          }
        },
        onDismissed: (_) => deleteWithUndo(context, birthday, haptic: false),
        background: ColoredBox(
          color: colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Icon(
                Icons.delete_outline_rounded,
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ),
        child: Card(
          margin: EdgeInsets.zero,
          child: MergeSemantics(
            child: Semantics(
              button: true,
              customSemanticsActions: {
                CustomSemanticsAction(label: context.l10n.delete): () =>
                    deleteWithUndo(context, birthday),
              },
              child: InkWell(
                onTap: () => context.push(AppRoutes.person(birthday.id)),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: _TileContent(birthday: birthday, highlight: highlight),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TileContent extends ConsumerWidget {
  const _TileContent({required this.birthday, required this.highlight});

  final Birthday birthday;
  final MatchRange? highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    final today = ref.watch(todayProvider);
    final days = birthday.daysUntilNext(today);
    // Mois abrégé : la date et l'âge tiennent sur une ligne.
    final date = DateFormat.MMMd(locale).format(birthday.nextOccurrence(today));
    final fullName = birthday.fullName;
    final picture = birthday.picture;

    final categories = birthday.categoriesFrom(ref.watch(categoriesProvider));

    // L'anneau est muet pour TalkBack : les catégories sont lues en clair.
    final categoryLabel = [
      for (final category in categories) category.localizedName(context),
    ].join(', ');
    final ring = AnKiAvatar(
      name: fullName,
      image: picture != null ? MemoryImage(picture) : null,
      ringColors: [
        for (final category in categories) category.tones(context).color,
      ],
    );
    // Sans année de naissance, la date seule : aucun âge inventé.
    final when = switch (birthday.turningAge(today)) {
      final age? => context.l10n.agendaLine(date, age),
      null => date,
    };
    final whenStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final countdown = _Countdown(
      days: days,
      wished: days == 0 && birthday.isWished(today),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Une ligne de deux lignes de texte, toujours la même hauteur ; au
        // grand texte, ou quand la date ne tient plus sur une ligne (écran
        // étroit), avatar et orbite passent au-dessus et le texte prend
        // toute la largeur.
        final textWidth =
            constraints.maxWidth -
            AnKiAvatar.ringedExtent() -
            2 * AppSpacing.sm -
            OrbitCountdown.extentOf(context);
        final largeText = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;
        final stacked =
            largeText || !_fitsOnOneLine(context, when, whenStyle, textWidth);
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              _highlighted(context, fullName, highlight),
              // Le nom complet reste lu par TalkBack et sur la page.
              maxLines: stacked ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            Text(when, style: whenStyle),
          ],
        );
        if (stacked) {
          // Bâtie de bas en haut, la colonne se lit dans l'ordre de la
          // ligne : catégories, nom, date, puis le compte à rebours, bien
          // qu'il soit placé au-dessus. `min` la garde en haut de la carte :
          // de bas en haut, une colonne plus haute que son contenu le
          // collerait en bas.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            verticalDirection: VerticalDirection.up,
            children: [
              Semantics(label: categoryLabel, child: identity),
              const SizedBox(height: AppSpacing.xs),
              Row(children: [ring, const Spacer(), countdown]),
            ],
          );
        }
        return Row(
          children: [
            Semantics(label: categoryLabel, child: ring),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: identity),
            const SizedBox(width: AppSpacing.sm),
            countdown,
          ],
        );
      },
    );
  }
}

/// [text] tient sur une ligne de [width] au plus, à la taille de texte de
/// l'écran.
bool _fitsOnOneLine(
  BuildContext context,
  String text,
  TextStyle? style,
  double width,
) {
  if (width <= 0) return false;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout(maxWidth: width);
  final fits = !painter.didExceedMaxLines;
  painter.dispose();
  return fits;
}

/// [name] avec les lettres de [range] surlignées en clair de lune (le
/// surlignage calme de l'identité), comme une recherche dans la page : le
/// fond marque la plage sans dépendre de la seule couleur du texte.
TextSpan _highlighted(BuildContext context, String name, MatchRange? range) {
  if (range == null) return TextSpan(text: name);
  final moonlight = context.ankiColors.moonlight;
  return TextSpan(
    children: [
      TextSpan(text: name.substring(0, range.start)),
      TextSpan(
        text: name.substring(range.start, range.end),
        style: TextStyle(
          color: moonlight.color,
          backgroundColor: moonlight.container,
        ),
      ),
      TextSpan(text: name.substring(range.end)),
    ],
  );
}

/// Jours restants dans leur orbite (S3) : la proximité d'un coup d'œil. Le
/// jour J, l'orbite bouclée porte un gâteau en lotus, puis la coche menthe
/// une fois le vœu fait. TalkBack lit « Dans 12 jours », « Demain »…
class _Countdown extends StatelessWidget {
  const _Countdown({required this.days, required this.wished});

  final int days;

  /// L'anniversaire du jour est souhaité.
  final bool wished;

  @override
  Widget build(BuildContext context) {
    final colors = context.ankiColors;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dayColor = wished ? colors.success.color : colors.blossom.color;

    final orbit = ExcludeSemantics(
      child: OrbitCountdown(
        daysLeft: days,
        arcColor: days == 0 ? dayColor : null,
        child: days == 0
            ? Icon(
                wished ? Icons.check_rounded : Icons.cake_rounded,
                color: dayColor,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$days',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    context.l10n.orbitDaysUnit(days),
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
      ),
    );

    return Semantics(
      label: context.l10n.countdownDays(days),
      child: wished
          ? Semantics(label: context.l10n.wished, child: orbit)
          : orbit,
    );
  }
}
