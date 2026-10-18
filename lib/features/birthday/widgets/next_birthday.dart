import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/common/moon_phase.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_display.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Héros « prochain anniversaire » (signature S1) : la ou les personnes dont
/// l'anniversaire arrive en premier, empilées quand elles tombent le même jour.
/// Le jour J, il passe en fête : dégradé nuit → lotus et pleine lune.
///
/// Squelette pendant le chargement ; rien sans anniversaire, l'accueil
/// affichant alors son état vide.
class NextBirthdayCard extends ConsumerWidget {
  const NextBirthdayCard({super.key});

  /// Hauteur du squelette : celle d'une carte à taille de texte normale.
  static const double skeletonHeight = 104;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(birthdaysLoadingProvider);
    final nextBirthdays = ref.watch(nextBirthdaysProvider);
    final today = ref.watch(todayProvider);

    if (isLoading) {
      return const SkeletonBox(height: skeletonHeight, radius: AppRadii.lg);
    }
    if (nextBirthdays.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final (index, birthday) in nextBirthdays.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.xs),
          _HeroCard(birthday: birthday, today: today),
        ],
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.birthday, required this.today});

  final Birthday birthday;
  final DateTime today;

  static const _shape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.ankiColors;
    final isToday = birthday.daysUntilNext(today) == 0;
    // Le jour J, le dégradé de fête (S1) et sa couleur de texte.
    final onColor = isToday ? colors.onCelebration : colors.onHero;
    final picture = birthday.picture;
    final avatar = AnKiAvatar(
      name: birthday.fullName,
      image: picture != null ? MemoryImage(picture) : null,
      radius: 28,
    );
    final details = _HeroDetails(
      birthday: birthday,
      today: today,
      onColor: onColor,
    );
    // Sans année de naissance, aucun âge : le texte prend la place.
    final age = switch (birthday.turningAge(today)) {
      final turning? => _HeroAge(
        age: turning,
        isToday: isToday,
        onColor: onColor,
      ),
      null => null,
    };
    // Grand texte : avatar et âge passent au-dessus, le texte prend la largeur.
    final reflow = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;
    final identity = Padding(
      // Le jour J, les actions prennent le bas de la carte.
      padding: isToday
          ? const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            )
          : const EdgeInsets.all(AppSpacing.md),
      child: reflow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [avatar, const Spacer(), ?age]),
                const SizedBox(height: AppSpacing.sm),
                details,
              ],
            )
          : Row(
              children: [
                avatar,
                const SizedBox(width: AppSpacing.md),
                Expanded(child: details),
                if (age != null) ...[const SizedBox(width: AppSpacing.sm), age],
              ],
            ),
    );

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: _shape,
        gradient: isToday ? colors.celebration : colors.hero,
        shadows: colors.floatingShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: _shape,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toucher la personne ouvre sa fiche ; les actions du jour J
            // restent des cibles à part pour les lecteurs d'écran.
            MergeSemantics(
              child: Semantics(
                button: true,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    BirthdayFormSheet.show(context, birthdayToEdit: birthday);
                  },
                  splashColor: onColor.withValues(alpha: 0.12),
                  highlightColor: onColor.withValues(alpha: 0.08),
                  child: identity,
                ),
              ),
            ),
            if (isToday)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: WishActions(
                  birthday: birthday,
                  wished: birthday.isWished(today),
                  onColor: onColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Qui et quand : surtitre, nom, lune et compte à rebours, date. Le jour J,
/// la pleine lune et « Aujourd'hui » suffisent : la date est celle du jour.
class _HeroDetails extends StatelessWidget {
  const _HeroDetails({
    required this.birthday,
    required this.today,
    required this.onColor,
  });

  final Birthday birthday;
  final DateTime today;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Texte secondaire à 85 % : contraste AA sur tout le dégradé.
    final secondary = onColor.withValues(alpha: 0.85);
    final days = birthday.daysUntilNext(today);
    final moon = MoonPhase(
      daysLeft: days,
      size: 16,
      litColor: onColor,
      shadowColor: onColor.withValues(alpha: 0.25),
    );
    final name = Text(
      birthday.fullName,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: textTheme.titleLarge?.copyWith(color: onColor),
    );

    if (days == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              moon,
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  context.l10n.today,
                  style: textTheme.labelLarge?.copyWith(color: onColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          name,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.nextBirthday,
          style: textTheme.labelMedium?.copyWith(color: secondary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        name,
        const SizedBox(height: AppSpacing.xxs),
        // La date passe à la ligne plutôt que de déborder (grand texte).
        Wrap(
          spacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                moon,
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    days == 1
                        ? context.l10n.tomorrow
                        : context.l10n.inDays(days),
                    style: textTheme.labelLarge?.copyWith(color: onColor),
                  ),
                ),
              ],
            ),
            Text(
              birthday.formattedDate(context, includeYear: false),
              style: textTheme.bodyMedium?.copyWith(color: secondary),
            ),
          ],
        ),
      ],
    );
  }
}

/// Âge atteint au prochain anniversaire, en grand : « aura » au-dessus avant
/// le jour J, l'unité accordée dessous.
class _HeroAge extends StatelessWidget {
  const _HeroAge({
    required this.age,
    required this.isToday,
    required this.onColor,
  });

  final int age;
  final bool isToday;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.labelMedium?.copyWith(
      color: onColor.withValues(alpha: 0.85),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isToday) Text(context.l10n.heroTurning, style: secondary),
        Text(
          '$age',
          style: textTheme.headlineSmall?.copyWith(
            color: onColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(context.l10n.heroAgeUnit(age), style: secondary),
      ],
    );
  }
}
