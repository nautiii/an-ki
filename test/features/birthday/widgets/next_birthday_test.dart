import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/common/orbit_countdown.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/blossom_rain.dart';
import 'package:an_ki/features/birthday/widgets/next_birthday.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/haptics.dart';
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

void main() {
  final today = DateTime(2026, 3, 12);

  Birthday relative(
    int daysAhead, {
    String id = '1',
    String name = 'Alice',
    String surname = 'Wonderland',
    Uint8List? picture,
    bool yearKnown = true,
    List<int> wishedYears = const [],
  }) {
    final target = today.add(Duration(days: daysAhead));
    return Birthday(
      id: id,
      name: name,
      surname: surname,
      date: BirthDate(
        year: yearKnown ? 1990 : null,
        month: target.month,
        day: target.day,
      ),
      picture: picture,
      wishedYears: wishedYears,
    );
  }

  /// La carte sur la largeur utile d'un téléphone de 360 dp (marges ôtées).
  Future<void> pumpCard(
    WidgetTester tester, {
    required List<Birthday> birthdays,
    bool isLoading = false,
  }) async {
    await tester.pumpHarness(
      const Center(child: SizedBox(width: 312, child: NextBirthdayCard())),
      overrides: [
        birthdaysProvider.overrideWithValue(
          isLoading ? const AsyncLoading() : AsyncData(birthdays),
        ),
        clockProvider.overrideWithValue(() => today),
        currentUidProvider.overrideWithValue('fake-uid'),
        userProfileProvider.overrideWithValue(const AsyncData(null)),
        categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
        birthdayRepositoryProvider.overrideWithValue(
          RecordingBirthdayRepository(),
        ),
      ],
      routes: {
        for (final birthday in birthdays)
          AppRoutes.person(birthday.id): (_) => Text('Page ${birthday.id}'),
      },
    );
  }

  testWidgets('shows nothing when there is no birthday', (tester) async {
    await pumpCard(tester, birthdays: const []);
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(SkeletonBox), findsNothing);
  });

  testWidgets('shows a skeleton while loading', (tester) async {
    await pumpCard(tester, birthdays: const [], isLoading: true);
    await tester.pump();

    expect(find.byType(SkeletonBox), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows who, when and how old', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(3)]);
      await tester.pumpAndSettle();

      expect(find.text('Dans 3 jours'), findsOneWidget);
      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('AW'), findsOneWidget);
      expect(find.text('15 mars'), findsOneWidget);
      // L'âge atteint au prochain anniversaire, dans son orbite.
      expect(
        find.descendant(
          of: find.byType(OrbitCountdown),
          matching: find.text('36'),
        ),
        findsOneWidget,
      );
      expect(find.text('ans'), findsOneWidget);
      // Sur un téléphone de 360 dp, la carte reste en ligne : le nom entre
      // l'avatar et l'orbite (empilée, il commencerait sous l'avatar).
      final name = tester.getRect(find.text('Alice Wonderland'));
      expect(
        name.left,
        greaterThan(tester.getRect(find.byType(AnKiAvatar)).right),
      );
      expect(
        name.right,
        lessThanOrEqualTo(tester.getRect(find.byType(OrbitCountdown)).left),
      );
    });
  });

  testWidgets('shows no age without a birth year', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(3, yearKnown: false)]);
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('Dans 3 jours'), findsOneWidget);
      expect(find.text('15 mars'), findsOneWidget);
      // Sans âge, l'orbite porte les jours restants.
      expect(find.text('3'), findsOneWidget);
      expect(find.text('jours'), findsOneWidget);
      expect(find.text('ans'), findsNothing);
    });
  });

  /// Dégradé de la carte du héros, et les couleurs de marque attendues.
  (Gradient?, AnKiColors) heroGradient(WidgetTester tester) {
    final card = find
        .descendant(
          of: find.byType(NextBirthdayCard),
          matching: find.byType(DecoratedBox),
        )
        .first;
    final decoration =
        tester.widget<DecoratedBox>(card).decoration as ShapeDecoration;
    return (decoration.gradient, tester.element(card).ankiColors);
  }

  testWidgets('celebrates a birthday happening today', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(0, picture: transparentPng)]);
      await tester.pumpAndSettle();

      expect(find.text("Aujourd'hui 🎉"), findsOneWidget);
      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text("fête ses 36 ans aujourd'hui"), findsOneWidget);
      expect(find.text('36'), findsOneWidget);
      expect(find.text('ans'), findsOneWidget);
      // Le jour même : ni orbite, ni compte à rebours, ni la date du jour.
      expect(find.byType(OrbitCountdown), findsNothing);
      expect(find.textContaining('Dans'), findsNothing);
      expect(find.text('12 mars'), findsNothing);
      final (gradient, colors) = heroGradient(tester);
      expect(gradient, colors.celebration);
    });
  });

  testWidgets('shows the wished pill instead of the actions', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(
        tester,
        birthdays: [
          relative(0, wishedYears: [2026]),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Souhaité'), findsOneWidget);
      // Le vœu fait, les actions s'effacent.
      expect(find.text('Souhaiter'), findsNothing);
      expect(find.text('Déjà souhaité'), findsNothing);
    });
  });

  testWidgets('reads the wish with the person once made', (tester) async {
    final semantics = tester.ensureSemantics();
    await mockNetworkImages(() async {
      await pumpCard(
        tester,
        birthdays: [
          relative(0, wishedYears: [2026]),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Alice Wonderland')).label,
        "Aujourd'hui 🎉\nAlice Wonderland\n"
        "fête ses 36 ans aujourd'hui\nSouhaité",
      );
    });
    semantics.dispose();
  });

  testWidgets('celebrates a birthday of the day without a birth year', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(0, yearKnown: false)]);
      await tester.pumpAndSettle();

      expect(find.text("fête son anniversaire aujourd'hui"), findsOneWidget);
      expect(find.text('ans'), findsNothing);
      expect(find.text('Souhaiter'), findsOneWidget);
    });
  });

  testWidgets('offers no wish action before the day', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(3)]);
      await tester.pumpAndSettle();

      expect(find.text('Déjà souhaité'), findsNothing);
      expect(find.text('Souhaité'), findsNothing);
    });
  });

  testWidgets('keeps the person and the wish action apart for TalkBack', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(0)]);
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Alice Wonderland')),
        isSemantics(
          label:
              "Aujourd'hui 🎉\nAlice Wonderland\n"
              "fête ses 36 ans aujourd'hui",
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('Souhaiter'), findsOneWidget);
      expect(find.bySemanticsLabel('Déjà souhaité'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
    semantics.dispose();
  });

  testWidgets('keeps the birthday of the day whole at 200 % text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(0)]);
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('Souhaiter'), findsOneWidget);
      expect(find.text('Déjà souhaité'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('lets the petals fall once on the day', (tester) async {
    final haptics = recordHaptics(tester);
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(0)]);
      await tester.pump();

      expect(find.byType(BlossomRain), findsOneWidget);
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NextBirthdayCard)),
      );
      expect(container.read(celebratedTodayProvider), {'1'});
      await tester.pumpAndSettle();
    });
  });

  testWidgets('keeps the petals still when animations are off', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final haptics = recordHaptics(tester);
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(0)]);
      await tester.pump();

      expect(haptics, isEmpty);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NextBirthdayCard)),
      );
      expect(container.read(celebratedTodayProvider), isEmpty);
    });
  });

  testWidgets('keeps the dusk gradient before the day', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(3)]);
      await tester.pumpAndSettle();

      final (gradient, colors) = heroGradient(tester);
      expect(gradient, colors.hero);
    });
  });

  testWidgets('agrees the age unit for a first birthday', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(
        tester,
        birthdays: [
          Birthday(
            id: 'baby',
            name: 'Nina',
            surname: '',
            date: BirthDate(year: 2025, month: today.month, day: today.day),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('an'), findsOneWidget);
      expect(find.text('ans'), findsNothing);
    });
  });

  testWidgets('labels a birthday happening tomorrow', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(1)]);
      await tester.pumpAndSettle();

      expect(find.text('Demain'), findsOneWidget);
    });
  });

  testWidgets('stacks every same-day birthday', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(
        tester,
        birthdays: [
          relative(2),
          relative(2, id: '2', name: 'Bob', surname: 'Builder'),
          relative(9, id: '3', name: 'Carl', surname: 'Later'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('Bob Builder'), findsOneWidget);
      expect(find.text('Carl Later'), findsNothing);
    });
  });

  testWidgets('tapping the card opens the person page', (tester) async {
    final haptics = recordHaptics(tester);
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(3)]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice Wonderland'));
      await tester.pumpAndSettle();

      expect(find.text('Page 1'), findsOneWidget);
      // Ouvrir n'est pas une action réussie : pas de vibration.
      expect(haptics, isEmpty);
    });
  });

  testWidgets('reads as a single button for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(3)]);
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Alice Wonderland')),
        isSemantics(
          label: 'Dans 3 jours\nAlice Wonderland\n15 mars\nAura 36 ans',
          isButton: true,
          hasTapAction: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
    semantics.dispose();
  });

  testWidgets('keeps everything whole at 200 % text on a small phone', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(12)]);
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('Dans 12 jours'), findsOneWidget);
      expect(find.text('24 mars'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('keeps a card without age whole at 200 % text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(12, yearKnown: false)]);
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('ans'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('reads a stacked card in the order of a single row', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(12)]);
      await tester.pumpAndSettle();

      // L'orbite est au-dessus du nom, mais l'âge se lit en dernier.
      expect(
        tester.getSemantics(find.text('Alice Wonderland')).label,
        'Dans 12 jours\nAlice Wonderland\n24 mars\nAura 36 ans',
      );
    });
    semantics.dispose();
  });

  testWidgets('keeps many days without age inside the orbit at 150 % text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(120, yearKnown: false)]);
      await tester.pumpAndSettle();

      expect(find.text('120'), findsOneWidget);
      expect(find.text('jours'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('celebrates a birth of the day without a zero age', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pumpCard(
        tester,
        birthdays: [
          Birthday(
            id: 'born',
            name: 'Nina',
            surname: '',
            date: BirthDate(
              year: today.year,
              month: today.month,
              day: today.day,
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text("fête son anniversaire aujourd'hui"), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });
}
