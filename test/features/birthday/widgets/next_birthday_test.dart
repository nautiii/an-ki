import 'dart:convert';

import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
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
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

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
    RecordingBirthdayRepository? repository,
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
          repository ?? RecordingBirthdayRepository(),
        ),
      ],
    );
  }

  testWidgets('shows nothing when there is no birthday', (tester) async {
    await pumpCard(tester, birthdays: const []);
    await tester.pumpAndSettle();

    expect(find.text('Prochain anniversaire'), findsNothing);
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

      expect(find.text('Prochain anniversaire'), findsOneWidget);
      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('AW'), findsOneWidget);
      expect(find.text('Dans 3 jours'), findsOneWidget);
      expect(find.text('15 mars'), findsOneWidget);
      // L'âge atteint au prochain anniversaire, annoncé par « aura ».
      expect(find.text('aura'), findsOneWidget);
      expect(find.text('36'), findsOneWidget);
      expect(find.text('ans'), findsOneWidget);
    });
  });

  testWidgets('shows no age without a birth year', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(3, yearKnown: false)]);
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('Dans 3 jours'), findsOneWidget);
      expect(find.text('15 mars'), findsOneWidget);
      expect(find.text('aura'), findsNothing);
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
      await pumpCard(tester, birthdays: [relative(0, picture: _png)]);
      await tester.pumpAndSettle();

      expect(find.text("Aujourd'hui 🎉"), findsOneWidget);
      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('36'), findsOneWidget);
      expect(find.text('ans'), findsOneWidget);
      // Le jour même : ni « aura », ni surtitre, ni la date du jour.
      expect(find.text('aura'), findsNothing);
      expect(find.text('Prochain anniversaire'), findsNothing);
      expect(find.text('12 mars'), findsNothing);
      final (gradient, colors) = heroGradient(tester);
      expect(gradient, colors.celebration);
    });
  });

  testWidgets('marks today\'s birthday as wished, with undo', (tester) async {
    final repository = RecordingBirthdayRepository();
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(0)], repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Déjà souhaité'));
      await tester.pump();

      expect(repository.wished, [('1', 2026)]);
      expect(
        find.text('Anniversaire de Alice Wonderland souhaité'),
        findsOneWidget,
      );
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
      expect(find.text('Déjà souhaité'), findsNothing);
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
          label: "Aujourd'hui 🎉\nAlice Wonderland\n36\nans",
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

  /// Relève les vibrations demandées pendant le test.
  List<Object?> recordHaptics(WidgetTester tester) {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return haptics;
  }

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

  testWidgets('tapping the card opens the edit sheet', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(3)]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice Wonderland'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier'), findsOneWidget);
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
          label:
              'Prochain anniversaire\nAlice Wonderland\nDans 3 jours\n'
              '15 mars\naura\n36\nans',
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
}
