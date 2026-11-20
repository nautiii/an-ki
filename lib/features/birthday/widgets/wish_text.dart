import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/wish_suggestions.dart';
import 'package:an_ki/l10n/app_localizations.dart';

/// Textes de [suggestions] adressés à [name], dans leur ordre : le premier
/// est celui qu'envoie « Souhaiter » (`wishSuggestionsProvider`).
List<String> wishTexts(
  AppLocalizations l10n,
  String name,
  List<WishSuggestion> suggestions,
) => [for (final suggestion in suggestions) wishText(l10n, name, suggestion)];

/// Premier vœu proposé par AnKi parmi [suggestions], sans le message propre
/// à [birthday] : celui qu'un message vide ou effacé laisserait envoyer.
String suggestedWishText(
  AppLocalizations l10n,
  Birthday birthday,
  List<WishSuggestion> suggestions,
) => wishText(
  l10n,
  birthday.name,
  suggestions.firstWhere((suggestion) => suggestion is! OwnWish),
);

/// Texte de [suggestion] adressé à [name], tiré de l'ARB.
String wishText(
  AppLocalizations l10n,
  String name,
  WishSuggestion suggestion,
) => switch (suggestion) {
  OwnWish(:final text) => text,
  MilestoneWish(:final age, circle: WishCircle.work) =>
    l10n.wishSuggestionMilestoneWork(name, age),
  MilestoneWish(:final age) => l10n.wishSuggestionMilestone(name, switch (age) {
    1 => 'first',
    18 => 'adult',
    _ => 'other',
  }, age),
  TemplateWish(:final tone, :final circle, :final variant, :final belated) =>
    switch ((tone, belated)) {
      (WishTone.short, false) => l10n.wishSuggestionShort(
        name,
        _variantKey(variant),
      ),
      (WishTone.warm, false) => l10n.wishSuggestionWarm(
        name,
        _styleKey(circle, variant),
      ),
      (WishTone.light, false) => l10n.wishSuggestionLight(
        name,
        // Le ton léger n'existe pas au travail : neutre, au cas où.
        _styleKey(
          circle == WishCircle.work ? WishCircle.other : circle,
          variant,
        ),
      ),
      (WishTone.short, true) => l10n.wishSuggestionBelatedShort(
        name,
        _variantKey(variant),
      ),
      (WishTone.warm, true) => l10n.wishSuggestionBelatedWarm(
        name,
        _styleKey(
          circle == WishCircle.work ? WishCircle.work : WishCircle.other,
          variant,
        ),
      ),
      (WishTone.light, true) => l10n.wishSuggestionBelatedLight(
        name,
        _variantKey(variant),
      ),
    },
};

/// Cas d'un `select` à trois variantes : `a`, `b`, puis `other` (le cas
/// obligatoire de l'ICU).
String _variantKey(int variant) => switch (variant) {
  0 => 'a',
  1 => 'b',
  _ => 'other',
};

/// Cas d'un `select` par cercle et variante (`familyA`, `workC`…) ; la
/// dernière variante du cercle neutre est le cas obligatoire `other`.
String _styleKey(WishCircle circle, int variant) {
  if (circle == WishCircle.other && variant >= 2) return 'other';
  return '${circle.name}${const ['A', 'B', 'C'][variant.clamp(0, 2)]}';
}
