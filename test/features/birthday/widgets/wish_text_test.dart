import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/wish_suggestions.dart';
import 'package:an_ki/features/birthday/widgets/wish_text.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));
  const nbsp = ' ';

  /// Tous les vœux possibles : modèles, âges marquants (travail compris).
  List<WishSuggestion> everyWish() => [
    for (final tone in WishTone.values)
      for (final circle in WishCircle.values)
        for (final belated in [false, true])
          for (var variant = 0; variant < wishVariantCount; variant++)
            TemplateWish(
              tone: tone,
              circle: circle,
              variant: variant,
              belated: belated,
            ),
    for (final circle in WishCircle.values)
      for (final age in [1, 18, 30]) MilestoneWish(age: age, circle: circle),
  ];

  final emoji = RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true);

  test('pins a few French and English wishes', () {
    expect(
      wishText(
        fr,
        'Léa',
        const MilestoneWish(age: 30, circle: WishCircle.friends),
      ),
      'Joyeux anniversaire Léa$nbsp! 30${nbsp}ans, ça se fête 🎉',
    );
    expect(
      wishText(
        en,
        'Léa',
        const MilestoneWish(age: 30, circle: WishCircle.friends),
      ),
      'Happy birthday Léa! 30 is worth celebrating 🎉',
    );
    expect(
      wishText(
        fr,
        'Hugo',
        const MilestoneWish(age: 40, circle: WishCircle.work),
      ),
      'Joyeux anniversaire Hugo pour ces 40${nbsp}ans$nbsp!',
    );
    expect(
      wishText(
        fr,
        'Chloé',
        const TemplateWish(
          tone: WishTone.warm,
          circle: WishCircle.family,
          variant: 0,
        ),
      ),
      'Joyeux anniversaire Chloé$nbsp! Je t\'embrasse très fort',
    );
    expect(
      wishText(
        en,
        'Hugo',
        const TemplateWish(
          tone: WishTone.light,
          circle: WishCircle.other,
          variant: 2,
          belated: true,
        ),
      ),
      'Better late than never: happy birthday Hugo! 🎉',
    );
  });

  test('the saved message is sent as written', () {
    expect(wishText(fr, 'Léa', const OwnWish('Coucou !')), 'Coucou !');
  });

  for (final (language, l10n) in [('fr', fr), ('en', en)]) {
    test('$language: every wish names the person, one emoji at most', () {
      for (final wish in everyWish()) {
        final text = wishText(l10n, 'Zoé', wish);
        expect(text, contains('Zoé'), reason: '$wish');
        expect(
          emoji.allMatches(text).length,
          lessThanOrEqualTo(1),
          reason: text,
        );
      }
    });

    test('$language: the variants of a tone and circle differ', () {
      for (final tone in WishTone.values) {
        for (final circle in WishCircle.values) {
          for (final belated in [false, true]) {
            final texts = {
              for (var variant = 0; variant < wishVariantCount; variant++)
                wishText(
                  l10n,
                  'Zoé',
                  TemplateWish(
                    tone: tone,
                    circle: circle,
                    variant: variant,
                    belated: belated,
                  ),
                ),
            };
            expect(texts, hasLength(wishVariantCount), reason: '$tone $circle');
          }
        }
      }
    });
  }

  test('French: neutral in gender, a no-break space before « ! ? : »', () {
    for (final wish in everyWish()) {
      final text = wishText(fr, 'Zoé', wish);
      expect(
        text,
        isNot(matches(RegExp('[Dd]ésolée?|[Cc]ontente?|[Pp]rête?'))),
      );
      expect(text, isNot(matches(RegExp(r'[^ ][!?:]'))), reason: text);
    }
  });

  test('French: no « tu » or « vous » to a colleague', () {
    // Mots entiers : `\b` d'une RegExp Dart ignore les lettres accentuées
    // (« fête » contiendrait « te »).
    final pronoun = RegExp(
      r"(^|\s)(tu|te|toi|ta|ton|tes|vous|votre|vos)(?=[\s,.!?]|$)|(^|\s)t'",
    );
    for (final wish in everyWish()) {
      final work = switch (wish) {
        TemplateWish(:final circle) ||
        MilestoneWish(:final circle) => circle == WishCircle.work,
        OwnWish() => false,
      };
      if (!work) continue;
      final text = wishText(fr, 'Zoé', wish);
      expect(pronoun.hasMatch(text), isFalse, reason: text);
    }
  });

  test(
    'wishTexts follows the order; suggestedWishText skips the saved one',
    () {
      const lea = Birthday(
        id: 'lea',
        name: 'Léa',
        surname: 'Martin',
        date: BirthDate(year: 1996, month: 11, day: 20),
        wishMessage: 'Coucou !',
      );
      final suggestions = lea.wishSuggestions(DateTime(2026, 11, 20));
      final texts = wishTexts(fr, lea.name, suggestions);

      expect(texts.first, 'Coucou !');
      expect(suggestedWishText(fr, lea, suggestions), texts[1]);
      expect(
        texts[1],
        'Joyeux anniversaire Léa$nbsp! 30${nbsp}ans, ça se fête 🎉',
      );
    },
  );
}
