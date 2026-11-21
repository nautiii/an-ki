import 'package:an_ki/core/common/orbit_countdown.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_hero.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:an_ki/features/birthday/widgets/person_header.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/features/birthday/widgets/wish_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  // Le 12 mars 2026.
  final today = DateTime(2026, 3, 12);

  Birthday alice(int daysAhead, {List<int> wishedYears = const []}) {
    final target = today.add(Duration(days: daysAhead));
    return Birthday(
      id: 'alice',
      name: 'Alice',
      surname: 'Wonderland',
      date: BirthDate(year: 1990, month: target.month, day: target.day),
      wishedYears: wishedYears,
    );
  }

  Future<void> pump(WidgetTester tester, Birthday birthday) async {
    await tester.pumpHarness(
      SingleChildScrollView(
        child: PersonHeader(birthday: birthday, today: today),
      ),
      overrides: [
        clockProvider.overrideWithValue(() => today),
        currentUidProvider.overrideWithValue('fake-uid'),
        birthdaysProvider.overrideWithValue(AsyncData([birthday])),
        userProfileProvider.overrideWithValue(const AsyncData(null)),
        categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
        birthdayRepositoryProvider.overrideWithValue(
          RecordingBirthdayRepository(),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  /// Dégradé de la surface du héros, et les couleurs de marque attendues.
  (Gradient?, AnKiColors) gradientOf(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(HeroSurface),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final colors = tester.element(find.byType(HeroSurface)).ankiColors;
    return ((box.decoration as ShapeDecoration).gradient, colors);
  }

  testWidgets('before the day: the lotus hero and the orbit', (tester) async {
    await pump(tester, alice(12));

    final (gradient, colors) = gradientOf(tester);
    expect(gradient, colors.hero);
    expect(find.byType(HeroComingIdentity), findsOneWidget);
    expect(find.byType(OrbitCountdown), findsOneWidget);
    expect(find.byType(WishActions), findsNothing);
  });

  testWidgets('the day itself: the celebration and the wish inside', (
    tester,
  ) async {
    await pump(tester, alice(0));

    final (gradient, colors) = gradientOf(tester);
    expect(gradient, colors.celebration);
    expect(
      tester.widget<HeroDayIdentity>(find.byType(HeroDayIdentity)).dayAfter,
      isFalse,
    );
    expect(find.byType(WishActions), findsOneWidget);
  });

  testWidgets('the day itself, once wished: no more actions', (tester) async {
    await pump(tester, alice(0, wishedYears: [2026]));

    expect(find.byType(WishActions), findsNothing);
    expect(find.byType(WishedPill), findsOneWidget);
  });

  testWidgets('the day after: the lotus hero, « Hier », no actions inside', (
    tester,
  ) async {
    await pump(tester, alice(-1));

    final (gradient, colors) = gradientOf(tester);
    expect(gradient, colors.hero);
    expect(
      tester.widget<HeroDayIdentity>(find.byType(HeroDayIdentity)).dayAfter,
      isTrue,
    );
    expect(find.text('Hier'), findsOneWidget);
    expect(find.byType(WishActions), findsNothing);
  });

  testWidgets('two days after: back to the coming birthday', (tester) async {
    await pump(tester, alice(-2));

    expect(find.byType(HeroComingIdentity), findsOneWidget);
    expect(find.text('Hier'), findsNothing);
  });

  /// Ce que TalkBack lit de l'identité : un seul nœud, l'en-tête de la page.
  SemanticsNode identity(WidgetTester tester) => tester.getSemantics(
    find
        .descendant(
          of: find.byType(PersonHeader),
          matching: find.byType(MergeSemantics),
        )
        .first,
  );

  testWidgets('stacked at 200 %, read in the order of the card', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester, alice(12));

    final node = identity(tester);
    expect(node, isSemantics(isHeader: true));
    expect(
      node.getSemanticsData().label,
      'Dans 12 jours\nAlice Wonderland\n24 mars 1990\nAura 36\u00a0ans',
    );
    semantics.dispose();
  });

  testWidgets('on the day, the bubble is a button of its own', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, alice(0));

    final bubble = tester.getSemantics(find.byType(WishBubble));
    expect(
      bubble,
      isSemantics(isButton: true, hint: 'Choisir un autre message'),
    );
    expect(
      identity(tester).getSemanticsData().label,
      isNot(contains(bubble.label)),
    );
    expect(
      identity(tester).getSemanticsData().label,
      contains('Alice Wonderland'),
    );
    semantics.dispose();
  });

  group('born on 29 February', () {
    Birthday leap() => const Birthday(
      id: 'leap',
      name: 'Léo',
      surname: 'Bissextil',
      date: BirthDate(year: 1992, month: 2, day: 29),
    );

    Future<void> pumpOn(WidgetTester tester, DateTime day) async {
      await tester.pumpHarness(
        SingleChildScrollView(
          child: PersonHeader(birthday: leap(), today: day),
        ),
        overrides: [
          clockProvider.overrideWithValue(() => day),
          currentUidProvider.overrideWithValue('fake-uid'),
          birthdaysProvider.overrideWithValue(AsyncData([leap()])),
          userProfileProvider.overrideWithValue(const AsyncData(null)),
          categoryRepositoryProvider.overrideWithValue(
            FakeCategoryRepository(),
          ),
          birthdayRepositoryProvider.overrideWithValue(
            RecordingBirthdayRepository(),
          ),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('celebrated on 1 March out of a leap year', (tester) async {
      await pumpOn(tester, DateTime(2027, 3));

      expect(find.byType(WishActions), findsOneWidget);
      expect(
        tester.widget<HeroDayIdentity>(find.byType(HeroDayIdentity)).dayAfter,
        isFalse,
      );
    });

    testWidgets('« Hier » on 2 March out of a leap year', (tester) async {
      await pumpOn(tester, DateTime(2027, 3, 2));

      expect(find.text('Hier'), findsOneWidget);
      expect(find.text('a eu 35 ans'), findsOneWidget);
    });

    testWidgets('« Hier » on 1 March of a leap year', (tester) async {
      await pumpOn(tester, DateTime(2028, 3));

      expect(find.text('Hier'), findsOneWidget);
      expect(find.text('a eu 36 ans'), findsOneWidget);
    });
  });
}
