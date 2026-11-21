import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/common/orbit_countdown.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_display.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:an_ki/features/birthday/widgets/blossom_rain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Surface du héros (signature S1) : dégradé lotus → nuage avant le jour J,
/// dégradé de fête le jour J ([celebrating]), avec les pétales (S4) qui
/// tombent derrière [child] une fois par personne et par jour.
class HeroSurface extends ConsumerWidget {
  const HeroSurface({
    super.key,
    required this.birthday,
    required this.celebrating,
    required this.child,
  });

  /// Sert d'identifiant aux pétales : une pluie par personne et par jour.
  final Birthday birthday;

  /// Le jour J : dégradé de fête et pétales.
  final bool celebrating;

  final Widget child;

  static const _shape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.ankiColors;

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: _shape,
        gradient: celebrating ? colors.celebration : colors.hero,
        shadows: colors.floatingShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: _shape,
        clipBehavior: Clip.antiAlias,
        child: celebrating
            ? Stack(
                children: [
                  // Les pétales (S4) tombent derrière le texte, une fois
                  // par personne et par jour.
                  Positioned.fill(
                    child: BlossomRain(
                      key: ValueKey('blossom-${birthday.id}'),
                      colors: colors.petals,
                      play: !ref.watch(
                        celebratedTodayProvider.select(
                          (ids) => ids.contains(birthday.id),
                        ),
                      ),
                      onPlay: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(celebratedTodayProvider.notifier)
                            .add(birthday.id);
                      },
                    ),
                  ),
                  child,
                ],
              )
            : child,
      ),
    );
  }
}

/// Le jour J : petit avatar et « Aujourd'hui », le nom, la phrase « fête ses
/// 30 ans aujourd'hui » (puis « ✓ Souhaité »), et l'âge en grand à droite (S6),
/// muet pour TalkBack : la phrase le dit déjà.
class HeroCelebrationIdentity extends StatelessWidget {
  const HeroCelebrationIdentity({
    super.key,
    required this.birthday,
    required this.today,
    required this.onColor,
    required this.wished,
  });

  final Birthday birthday;
  final DateTime today;
  final Color onColor;
  final bool wished;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Texte secondaire à 85 % : contraste AA sur tout le dégradé.
    final secondary = onColor.withValues(alpha: 0.85);
    // Né aujourd'hui : pas de « 0 » en grand, la phrase sans âge.
    final age = switch (birthday.turningAge(today)) {
      final turning? when turning > 0 => turning,
      _ => null,
    };
    final picture = birthday.picture;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AnKiAvatar(
                    name: birthday.fullName,
                    image: picture != null ? MemoryImage(picture) : null,
                    radius: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      context.l10n.today,
                      style: textTheme.labelLarge?.copyWith(color: secondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                birthday.fullName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(color: onColor),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    age != null
                        ? context.l10n.heroCelebrating(age)
                        : context.l10n.heroCelebratingNoAge,
                    style: textTheme.bodyMedium?.copyWith(color: secondary),
                  ),
                  if (wished) const WishedPill(dense: true),
                ],
              ),
            ],
          ),
        ),
        if (age != null) ...[
          const SizedBox(width: AppSpacing.md),
          ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$age',
                  style: textTheme.displaySmall?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  context.l10n.heroAgeUnit(age),
                  style: textTheme.labelMedium?.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Avant le jour J : l'avatar, « Dans 3 jours », le nom et la date, et l'âge
/// à venir dans son orbite (S3), qui se referme à l'approche du jour J. Sans
/// année de naissance, l'orbite porte les jours restants.
class HeroComingIdentity extends StatelessWidget {
  const HeroComingIdentity({
    super.key,
    required this.birthday,
    required this.today,
    required this.onColor,
  });

  final Birthday birthday;
  final DateTime today;
  final Color onColor;

  static const double _avatarRadius = 28;

  /// Diamètre de l'orbite à taille de texte normale.
  static const double _orbitDiameter = 72;

  /// Croissance de l'orbite avec le texte, tant qu'elle reste sur la ligne.
  static const double _orbitMaxScale = 1.2;

  /// Largeur de texte sous laquelle avatar et orbite passent au-dessus, à
  /// taille de texte normale.
  static const double _minTextWidth = 120;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = onColor.withValues(alpha: 0.85);
    final days = birthday.daysUntilNext(today);
    final age = birthday.turningAge(today);
    final picture = birthday.picture;
    final avatar = AnKiAvatar(
      name: birthday.fullName,
      image: picture != null ? MemoryImage(picture) : null,
      radius: _avatarRadius,
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.countdownDays(days),
          style: textTheme.labelLarge?.copyWith(color: secondary),
        ),
        Text(
          birthday.fullName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleLarge?.copyWith(color: onColor),
        ),
        Text(
          birthday.formattedDate(context, includeYear: false),
          style: textTheme.bodyMedium?.copyWith(color: secondary),
        ),
      ],
    );

    Widget orbit({double? maxTextScale}) {
      final drawn = ExcludeSemantics(
        child: OrbitCountdown(
          daysLeft: days,
          diameter: _orbitDiameter,
          maxTextScale: maxTextScale,
          trackColor: onColor.withValues(alpha: 0.25),
          arcColor: onColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${age ?? days}',
                style: textTheme.headlineSmall?.copyWith(
                  color: onColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                age != null
                    ? context.l10n.heroAgeUnit(age)
                    : context.l10n.orbitDaysUnit(days),
                style: textTheme.labelMedium?.copyWith(
                  color: secondary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
      // L'âge se lit « Aura 34 ans » ; les jours, déjà dits au-dessus du nom,
      // ne se relisent pas.
      return age != null
          ? Semantics(label: context.l10n.personTurning(age), child: drawn)
          : drawn;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final textWidth =
            constraints.maxWidth -
            2 * _avatarRadius -
            OrbitCountdown.extentOf(
              context,
              diameter: _orbitDiameter,
              maxTextScale: _orbitMaxScale,
            ) -
            2 * AppSpacing.md;
        // Grand texte ou écran étroit : avatar et orbite au-dessus, le texte
        // sur toute la largeur, l'orbite libre de grandir.
        final reflow =
            scaler.scale(16) / 16 > 1.5 ||
            textWidth < scaler.scale(_minTextWidth);
        if (reflow) {
          // Bâtie de bas en haut, comme une ligne d'agenda empilée : TalkBack
          // lit « Dans 3 jours », le nom, la date, puis l'âge, bien que
          // l'orbite soit au-dessus.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            verticalDirection: VerticalDirection.up,
            children: [
              details,
              const SizedBox(height: AppSpacing.sm),
              Row(children: [avatar, const Spacer(), orbit()]),
            ],
          );
        }
        return Row(
          children: [
            avatar,
            const SizedBox(width: AppSpacing.md),
            Expanded(child: details),
            const SizedBox(width: AppSpacing.md),
            orbit(maxTextScale: _orbitMaxScale),
          ],
        );
      },
    );
  }
}
