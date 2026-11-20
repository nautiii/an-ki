import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/wish_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Birthday person({
    String id = 'lea',
    int? year = 1996,
    int month = 11,
    int day = 20,
    String? wishMessage,
  }) => Birthday(
    id: id,
    name: 'Léa',
    surname: 'Martin',
    date: BirthDate(year: year, month: month, day: day),
    wishMessage: wishMessage,
  );

  final today = DateTime(2026, 11, 20);

  group('isMilestoneAge', () {
    test('1, 18 and every ten years', () {
      expect(
        [
          for (var age = 0; age <= 60; age++)
            if (isMilestoneAge(age)) age,
        ],
        [1, 10, 18, 20, 30, 40, 50, 60],
      );
    });
  });

  group('wishCircleOf', () {
    test('family first, then friends, then work', () {
      expect(
        wishCircleOf(['colleague', 'friend', 'family']),
        WishCircle.family,
      );
      expect(wishCircleOf(['colleague', 'bff']), WishCircle.friends);
      expect(wishCircleOf(['couple']), WishCircle.friends);
      expect(wishCircleOf(['colleague']), WishCircle.work);
      // Le nom est une clé : sa casse ne compte pas.
      expect(wishCircleOf(['Family']), WishCircle.family);
    });

    test('no predefined group is neutral', () {
      expect(wishCircleOf([]), WishCircle.other);
      expect(wishCircleOf(['other', 'my-own-group']), WishCircle.other);
    });
  });

  group('wishSuggestions', () {
    test('three suggestions: short, warm, light', () {
      final suggestions = person(year: 1993).wishSuggestions(today);

      expect(suggestions, hasLength(3));
      expect(
        [for (final s in suggestions) (s as TemplateWish).tone],
        [WishTone.short, WishTone.warm, WishTone.light],
      );
      expect(suggestions.every((s) => s is TemplateWish && !s.belated), isTrue);
    });

    test('a milestone age comes first on the day', () {
      for (final (year, age) in [(2025, 1), (2008, 18), (1996, 30)]) {
        expect(
          person(year: year).wishSuggestions(today).first,
          MilestoneWish(age: age, circle: WishCircle.other),
        );
      }
    });

    test('never an age without a birth year', () {
      final suggestions = person(year: null).wishSuggestions(today);

      expect(suggestions.whereType<MilestoneWish>(), isEmpty);
      expect((suggestions.first as TemplateWish).tone, WishTone.short);
    });

    test('the saved message comes first, the rest follows', () {
      final suggestions = person(wishMessage: 'Coucou !')
          .wishSuggestions(today);

      expect(suggestions, hasLength(3));
      expect(suggestions.first, const OwnWish('Coucou !'));
      expect(suggestions[1], isA<MilestoneWish>());
      expect((suggestions[2] as TemplateWish).tone, WishTone.warm);
    });

    test('work stays sober: two warm wishes, no light one', () {
      final suggestions = person(year: 1993)
          .wishSuggestions(today, circle: WishCircle.work);
      final templates = suggestions.cast<TemplateWish>();

      expect(templates.map((s) => s.tone), [
        WishTone.short,
        WishTone.warm,
        WishTone.warm,
      ]);
      expect(templates[1].variant, isNot(templates[2].variant));
      expect(templates.every((s) => s.circle == WishCircle.work), isTrue);
    });

    test('the day after: belated, without the age', () {
      final suggestions = person(day: 19).wishSuggestions(today);

      expect(suggestions.whereType<MilestoneWish>(), isEmpty);
      expect(suggestions.every((s) => s is TemplateWish && s.belated), isTrue);
    });

    test('on 1 January, a belated wish for 31 December', () {
      final suggestions = person(
        month: 12,
        day: 31,
      ).wishSuggestions(DateTime(2027));

      expect((suggestions.first as TemplateWish).belated, isTrue);
    });

    test('a 29 February birthday is wished on 1 March, belated on the 2nd', () {
      final leap = person(month: 2, day: 29);

      expect(
        leap.wishSuggestions(DateTime(2027, 3)).first,
        isA<TemplateWish>(),
      );
      expect(
        (leap.wishSuggestions(DateTime(2027, 3, 2)).first as TemplateWish)
            .belated,
        isTrue,
      );
    });

    test('outside the wish window: the next birthday, not belated', () {
      final suggestions = person(year: 1997, day: 25).wishSuggestions(today);

      expect(suggestions.first, isA<TemplateWish>());
      expect(suggestions.cast<TemplateWish>().any((s) => s.belated), isFalse);
      // L'âge marquant du prochain anniversaire : 30 ans le 25.
      expect(
        person(day: 25).wishSuggestions(today).first,
        const MilestoneWish(age: 30, circle: WishCircle.other),
      );
    });

    test('stable through the day, changing with the year and the person', () {
      List<int> variants(Birthday birthday, DateTime day) => [
        for (final s in birthday.wishSuggestions(day))
          if (s is TemplateWish) s.variant,
      ];
      final lea = person(year: 1993);

      expect(
        variants(lea, DateTime(2026, 11, 20, 8)),
        variants(lea, DateTime(2026, 11, 20, 23, 59)),
      );
      final years = {
        for (var year = 2026; year < 2036; year++)
          variants(lea, DateTime(year, 11, 20)).first,
      };
      expect(years.length, greaterThan(1));
      final people = {
        for (var i = 0; i < 10; i++)
          variants(person(id: 'p$i', year: 1993), today).first,
      };
      expect(people.length, greaterThan(1));
    });

    test('variants stay in range', () {
      for (var i = 0; i < 50; i++) {
        for (final s in person(id: 'p$i', year: 1993).wishSuggestions(today)) {
          if (s is TemplateWish) {
            expect(s.variant, inInclusiveRange(0, wishVariantCount - 1));
          }
        }
      }
    });
  });
}
