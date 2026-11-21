import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_hero.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Héros « prochain anniversaire » (signature S1) : la ou les personnes dont
/// l'anniversaire arrive en premier, empilées quand elles tombent le même jour.
/// Avant le jour J, l'âge à venir tourne dans son orbite (S3) ; le jour J, la
/// carte passe en fête : dégradé nuit → lotus, phrase et âge en grand.
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

  @override
  Widget build(BuildContext context) {
    final colors = context.ankiColors;
    final isToday = birthday.daysUntilNext(today) == 0;
    // Le vœu fait, les actions s'effacent : la carte se resserre sur la
    // personne, la pastille « ✓ Souhaité » rejoint la phrase.
    final wished = isToday && birthday.isWished(today);
    final showActions = isToday && !wished;
    // Le jour J, le dégradé de fête (S1) et sa couleur de texte.
    final onColor = isToday ? colors.onCelebration : colors.onHero;

    return HeroSurface(
      birthday: birthday,
      celebrating: isToday,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toucher la personne ouvre sa page ; les actions du jour J
          // restent des cibles à part pour les lecteurs d'écran.
          MergeSemantics(
            child: Semantics(
              button: true,
              child: InkWell(
                onTap: () => context.push(AppRoutes.person(birthday.id)),
                splashColor: onColor.withValues(alpha: 0.12),
                highlightColor: onColor.withValues(alpha: 0.08),
                child: Padding(
                  // Les actions prennent le bas de la carte.
                  padding: showActions
                      ? const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.sm,
                        )
                      : const EdgeInsets.all(AppSpacing.md),
                  child: isToday
                      ? HeroCelebrationIdentity(
                          birthday: birthday,
                          today: today,
                          onColor: onColor,
                          wished: wished,
                        )
                      : HeroComingIdentity(
                          birthday: birthday,
                          today: today,
                          onColor: onColor,
                        ),
                ),
              ),
            ),
          ),
          if (showActions)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: WishActions(birthday: birthday, onColor: onColor),
            ),
        ],
      ),
    );
  }
}
