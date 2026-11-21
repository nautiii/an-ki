import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
import 'package:an_ki/features/birthday/widgets/birthday_hero.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:flutter/material.dart';

/// En-tête de la page d'une personne : la carte du héros de l'accueil (S1),
/// en plus grand, le nom en titre de la page.
///
/// - Avant le jour : dégradé lotus → nuage, « Dans 12 jours », le nom, la
///   date de naissance et l'âge à venir dans son orbite (S3).
/// - Le jour J : dégradé de fête et pétales (S4), « fête ses 36 ans
///   aujourd'hui », l'âge en grand, puis la bulle du vœu, « Souhaiter » et
///   « Déjà souhaité » tant qu'il n'est pas fait.
/// - Le lendemain : la carte reste pastel, « Hier », « a eu 36 ans » ; le vœu
///   en retard se fait sous la carte, sur la surface calme (le framboise de
///   « Déjà souhaité » ne contraste qu'à 3,8:1 sur le pastel).
class PersonHeader extends StatelessWidget {
  const PersonHeader({super.key, required this.birthday, required this.today});

  final Birthday birthday;
  final DateTime today;

  /// Hauteur du squelette : celle d'un en-tête à taille de texte normale.
  static const double skeletonHeight = 152;

  @override
  Widget build(BuildContext context) {
    final colors = context.ankiColors;
    final isToday = birthday.daysUntilNext(today) == 0;
    final dayAfter = !isToday && birthday.canWish(today);
    final wished = birthday.isWished(today);
    final onColor = isToday ? colors.onCelebration : colors.onHero;

    return HeroSurface(
      birthday: birthday,
      celebrating: isToday,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Un seul nœud TalkBack, l'en-tête de la page, lu dans l'ordre
            // de la carte (empilée à 200 % comprise) : « Dans 12 jours, Léa
            // Martin, 24 octobre 1990, Aura 36 ans ». La bulle et les
            // boutons du jour J restent des cibles à part.
            MergeSemantics(
              child: isToday || dayAfter
                  ? HeroDayIdentity(
                      birthday: birthday,
                      today: today,
                      onColor: onColor,
                      wished: wished,
                      dayAfter: dayAfter,
                      prominent: true,
                    )
                  : HeroComingIdentity(
                      birthday: birthday,
                      today: today,
                      onColor: onColor,
                      prominent: true,
                    ),
            ),
            if (isToday && !wished) ...[
              const SizedBox(height: AppSpacing.md),
              WishActions(birthday: birthday, onColor: onColor),
            ],
          ],
        ),
      ),
    );
  }
}
