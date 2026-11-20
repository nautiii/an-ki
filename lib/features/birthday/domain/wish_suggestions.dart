import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
import 'package:an_ki/features/birthday/domain/stable_hash.dart';
import 'package:flutter/foundation.dart';

/// Cercle d'une personne, qui donne le ton des vœux suggérés : tiré de ses
/// groupes prédéfinis.
enum WishCircle {
  family,
  friends,

  /// Sobre : ni tu ni vous, pas de ton léger.
  work,

  /// Aucun groupe prédéfini (ou seulement des groupes créés) : neutre.
  other,
}

/// Ton d'un vœu suggéré.
enum WishTone { short, warm, light }

/// Nombre de variantes de chaque ton (les textes de l'ARB en ont autant).
const wishVariantCount = 3;

/// Nombre de vœux suggérés au plus.
const wishSuggestionCount = 3;

/// Un vœu suggéré, décrit sans son texte : l'écran le traduit (ARB).
@immutable
sealed class const WishSuggestion();

/// Le message enregistré pour la personne.
final class const OwnWish(final String text) extends WishSuggestion {
  @override
  bool operator ==(Object other) => other is OwnWish && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// Un âge marquant ([isMilestoneAge]), le jour J et l'année connue.
final class const MilestoneWish({
  required final int age,
  required final WishCircle circle,
}) extends WishSuggestion {
  @override
  bool operator ==(Object other) =>
      other is MilestoneWish && other.age == age && other.circle == circle;

  @override
  int get hashCode => Object.hash(age, circle);
}

/// Un modèle de vœu : un ton, un cercle, une variante (0 à
/// [wishVariantCount] − 1), et s'il arrive après le jour J.
final class const TemplateWish({
  required final WishTone tone,
  required final WishCircle circle,
  required final int variant,
  final bool belated = false,
}) extends WishSuggestion {
  @override
  bool operator ==(Object other) =>
      other is TemplateWish &&
      other.tone == tone &&
      other.circle == circle &&
      other.variant == variant &&
      other.belated == belated;

  @override
  int get hashCode => Object.hash(tone, circle, variant, belated);
}

/// Vrai pour un âge qui se fête : 1 an, 18 ans, chaque dizaine.
bool isMilestoneAge(int age) =>
    age == 1 || age == 18 || (age > 0 && age % 10 == 0);

/// Cercle tiré des noms des groupes prédéfinis d'une personne (`family`,
/// `friend`…, la clé que porte [BirthdayCategory.name]) : la famille
/// d'abord, puis les amis (meilleur ami, couple compris), puis le travail.
/// Un groupe créé par l'utilisateur ne compte pas, quel que soit son nom :
/// l'appelant ne passe que les prédéfinis.
WishCircle wishCircleOf(Iterable<String> predefinedNames) {
  final ids = {for (final name in predefinedNames) name.toLowerCase()};
  if (ids.contains('family')) return WishCircle.family;
  if (ids.contains('friend') || ids.contains('bff') || ids.contains('couple')) {
    return WishCircle.friends;
  }
  if (ids.contains('colleague')) return WishCircle.work;
  return WishCircle.other;
}

/// Vœux suggérés pour une personne.
extension WishSuggestions on Birthday {
  /// Les [wishSuggestionCount] vœux suggérés à [today] : pour l'anniversaire
  /// du jour, celui d'hier (en retard, [BirthdayWishes.canWish]) ou sinon le
  /// prochain :
  /// 1. son message à elle, s'il existe ;
  /// 2. son âge s'il est marquant le jour J (jamais sans année), sinon un
  ///    message court ;
  /// 3. un tendre, puis un léger — au travail, un second tendre.
  ///
  /// [circle] donne le ton ([wishCircleOf]).
  ///
  /// La variante dépend de la personne et de l'année de l'anniversaire :
  /// stable toute la journée (et le lendemain), elle change chaque année et
  /// d'une personne à l'autre.
  List<WishSuggestion> wishSuggestions(
    DateTime today, {
    WishCircle circle = WishCircle.other,
  }) {
    // Le jour J ou le lendemain, l'anniversaire qui vient de passer ;
    // sinon le prochain (l'aperçu de la page de la personne).
    final day = DateTime(today.year, today.month, today.day);
    final target = canWish(today)
        ? lastOccurrence(today)
        : nextOccurrence(today);
    final belated = target.isBefore(day);
    final seed = stableHash('$id/${target.year}');
    int variant(int offset) => (seed + offset) % wishVariantCount;
    TemplateWish template(WishTone tone, int offset) => TemplateWish(
      tone: tone,
      circle: circle,
      variant: variant(offset),
      belated: belated,
    );

    final birthYear = date.year;
    final age = birthYear == null ? null : target.year - birthYear;
    final own = wishMessage;
    return [
      if (own != null) OwnWish(own),
      if (!belated && age != null && isMilestoneAge(age))
        MilestoneWish(age: age, circle: circle)
      else
        template(WishTone.short, 0),
      template(WishTone.warm, 1),
      if (circle == WishCircle.work)
        template(WishTone.warm, 2)
      else
        template(WishTone.light, 2),
    ].take(wishSuggestionCount).toList();
  }
}
