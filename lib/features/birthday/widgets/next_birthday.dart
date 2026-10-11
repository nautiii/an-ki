import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/common/moon_phase.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_display.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Héros « prochain anniversaire » (signature S1) : la ou les personnes dont
/// l'anniversaire arrive en premier, empilées quand elles tombent le même jour.
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
    final picture = birthday.picture;
    final avatar = AnKiAvatar(
      name: '${birthday.name} ${birthday.surname}',
      image: picture != null ? MemoryImage(picture) : null,
      radius: 28,
    );
    final details = _HeroDetails(birthday: birthday, today: today);
    final age = _HeroAge(age: birthday.ageOn(today));
    // Grand texte : avatar et âge passent au-dessus, le texte prend la largeur.
    final reflow = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: _shape,
        gradient: colors.hero,
        shadows: colors.floatingShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: _shape,
        clipBehavior: Clip.antiAlias,
        child: MergeSemantics(
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                BirthdayFormSheet.show(context, birthdayToEdit: birthday);
              },
              splashColor: colors.onHero.withValues(alpha: 0.12),
              highlightColor: colors.onHero.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: reflow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [avatar, const Spacer(), age]),
                          const SizedBox(height: AppSpacing.sm),
                          details,
                        ],
                      )
                    : Row(
                        children: [
                          avatar,
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: details),
                          const SizedBox(width: AppSpacing.sm),
                          age,
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Qui et quand : surtitre, nom, lune et compte à rebours, date.
class _HeroDetails extends StatelessWidget {
  const _HeroDetails({required this.birthday, required this.today});

  final Birthday birthday;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onHero = context.ankiColors.onHero;
    // Texte secondaire à 85 % : contraste AA sur tout le dégradé.
    final secondary = onHero.withValues(alpha: 0.85);
    final days = birthday.daysUntilNext(today);
    final countdown = switch (days) {
      0 => context.l10n.today,
      1 => context.l10n.tomorrow,
      _ => context.l10n.inDays(days),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.nextBirthday,
          style: textTheme.labelMedium?.copyWith(color: secondary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${birthday.name} ${birthday.surname}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleLarge?.copyWith(color: onHero),
        ),
        const SizedBox(height: AppSpacing.xxs),
        // La date passe à la ligne plutôt que de déborder (grand texte).
        Wrap(
          spacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MoonPhase(
                  daysLeft: days,
                  size: 16,
                  litColor: onHero,
                  shadowColor: onHero.withValues(alpha: 0.25),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    countdown,
                    style: textTheme.labelLarge?.copyWith(color: onHero),
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

/// Âge en grand, son unité dessous.
class _HeroAge extends StatelessWidget {
  const _HeroAge({required this.age});

  final int age;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onHero = context.ankiColors.onHero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$age',
          style: textTheme.headlineSmall?.copyWith(
            color: onHero,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          context.l10n.yearsOld,
          style: textTheme.labelMedium?.copyWith(
            color: onHero.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}
