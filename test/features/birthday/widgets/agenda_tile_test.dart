import 'dart:typed_data';

import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/common/orbit_countdown.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/label_tones.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_search.dart';
import 'package:an_ki/features/birthday/widgets/agenda_tile.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/haptics.dart';
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

void main() {
  final today = DateTime(2026, 10, 12);
  const family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe1be);
  const friend = BirthdayCategory(id: 'fri', name: 'friend', icon: 0xe1bf);

  Birthday birthday({
    List<String> categories = const ['fri', 'fam'],
    Uint8List? picture,
    BirthDate date = const BirthDate(year: 1990, month: 10, day: 24),
    String surname = 'Wonderland',
    List<int> wishedYears = const [],
  }) => Birthday(
    id: '1',
    name: 'Alice',
    surname: surname,
    date: date,
    categories: categories,
    picture: picture,
    wishedYears: wishedYears,
  );

  List<dynamic> overrides() => [
    clockProvider.overrideWithValue(() => today),
    currentUidProvider.overrideWithValue('fake-uid'),
    userProfileProvider.overrideWithValue(
      const AsyncData(
        UserProfile(id: 'fake-uid', name: 'A', surname: 'B', locale: 'fr'),
      ),
    ),
    birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
    categoryRepositoryProvider.overrideWithValue(
      RecordingCategoryRepository([family, friend]),
    ),
  ];

  Future<void> pumpTile(
    WidgetTester tester,
    Birthday birthday, {
    MatchRange? highlight,
    double width = 312,
  }) => mockNetworkImages(() async {
    await tester.pumpHarness(
      Center(
        child: SizedBox(
          width: width,
          child: AgendaTile(birthday: birthday, highlight: highlight),
        ),
      ),
      overrides: overrides(),
      routes: {
        AppRoutes.person(birthday.id): (_) => Text('Page ${birthday.id}'),
      },
    );
    await tester.pumpAndSettle();
  });

  /// Le nom passe sous l'avatar plutôt qu'à sa droite.
  bool stacked(WidgetTester tester) =>
      tester.getTopLeft(find.text('Alice Wonderland')).dy >=
      tester.getBottomLeft(find.byType(AnKiAvatar)).dy;

  testWidgets('shows who, when, how old and how soon', (tester) async {
    await pumpTile(tester, birthday());

    expect(find.text('Alice Wonderland'), findsOneWidget);
    expect(find.text('24 octobre · 36 ans'), findsOneWidget);
    // Les jours restants dans leur orbite.
    expect(find.byType(OrbitCountdown), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('jours'), findsOneWidget);
  });

  testWidgets('shows the date alone without a birth year', (tester) async {
    await pumpTile(tester, birthday(date: const BirthDate(month: 10, day: 24)));

    expect(find.text('24 octobre'), findsOneWidget);
    expect(find.textContaining('ans'), findsNothing);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('names a person without a last name, no stray space', (
    tester,
  ) async {
    await pumpTile(tester, birthday(surname: ''));

    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('marks the letters a search found, on a tinted ground', (
    tester,
  ) async {
    await pumpTile(tester, birthday(), highlight: (start: 6, end: 10));

    final name = tester.widget<Text>(find.text('Alice Wonderland'));
    final parts = (name.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect([for (final part in parts) part.text], ['Alice ', 'Wond', 'erland']);
    expect(
      [for (final part in parts) part.style?.backgroundColor != null],
      [false, true, false],
    );
  });

  testWidgets('shows the name plain outside a search', (tester) async {
    await pumpTile(tester, birthday());

    final name = tester.widget<Text>(find.text('Alice Wonderland'));
    expect((name.textSpan! as TextSpan).children, isNull);
  });

  testWidgets('shows the wish of the day once made, like the hero', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpTile(
      tester,
      birthday(
        date: const BirthDate(year: 1990, month: 10, day: 12),
        wishedYears: const [2026],
      ),
      // La police de test, plus large, demande la largeur d'une ligne réelle.
      width: 480,
    );

    // L'orbite bouclée passe du gâteau à la coche, sans élargir la ligne.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.cake_rounded), findsNothing);
    expect(stacked(tester), isFalse);
    expect(
      tester.getSemantics(find.text('Alice Wonderland')).label,
      "Amis, Famille\nAlice Wonderland\n12 octobre · 36 ans\n"
      "Aujourd'hui\nSouhaité",
    );
    semantics.dispose();
  });

  testWidgets('shows no wish before it is made, nor after the day', (
    tester,
  ) async {
    await pumpTile(
      tester,
      birthday(date: const BirthDate(year: 1990, month: 10, day: 12)),
    );
    expect(find.byIcon(Icons.cake_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    // Souhaité hier : le vœu compte toujours, mais la ligne n'est plus celle
    // du jour.
    await pumpTile(
      tester,
      birthday(
        date: const BirthDate(year: 1990, month: 10, day: 11),
        wishedYears: const [2026],
      ),
    );
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('shows one day and reads tomorrow', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpTile(
      tester,
      birthday(date: const BirthDate(year: 1990, month: 10, day: 13)),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('jour'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Alice Wonderland')).label,
      endsWith('\nDemain'),
    );
    semantics.dispose();
  });

  testWidgets('rings the avatar with the categories, in the person order', (
    tester,
  ) async {
    await pumpTile(tester, birthday());

    final avatar = tester.widget<AnKiAvatar>(find.byType(AnKiAvatar));
    expect(avatar.ringColors, [
      LabelTones.of(1, Brightness.light).color, // ami
      LabelTones.of(0, Brightness.light).color, // famille
    ]);
  });

  testWidgets('keeps the ring room without categories', (tester) async {
    await pumpTile(
      tester,
      birthday(categories: const [], picture: transparentPng),
    );

    expect(
      tester.widget<AnKiAvatar>(find.byType(AnKiAvatar)).ringColors,
      isEmpty,
    );
  });

  testWidgets('reads the categories and offers deletion to TalkBack', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    // Sur une ligne : l'ordre de lecture est celui de la ligne.
    await pumpTile(tester, birthday(), width: 760);

    expect(
      tester.getSemantics(find.text('Alice Wonderland')),
      isSemantics(
        label: 'Amis, Famille\nAlice Wonderland\n24 octobre · 36 ans\nDans 12 jours',
        isButton: true,
        hasTapAction: true,
        customActions: [const CustomSemanticsAction(label: 'Supprimer')],
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('tapping opens the person page, without a vibration', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    await pumpTile(tester, birthday());

    await tester.tap(find.text('Alice Wonderland'));
    await tester.pumpAndSettle();

    expect(find.text('Page 1'), findsOneWidget);
    expect(haptics, isEmpty);
  });

  testWidgets('a swipe vibrates once, as it crosses its threshold', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    await pumpTile(tester, birthday());

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Alice Wonderland')),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    expect(haptics, isEmpty);
    await gesture.moveBy(const Offset(-260, 0));
    await tester.pump();
    expect(haptics, ['HapticFeedbackType.mediumImpact']);

    await gesture.up();
    await tester.pumpAndSettle();
    // Lâcher supprime sans vibrer une seconde fois.
    expect(
      find.text("Alice Wonderland n'est plus dans vos anniversaires"),
      findsOneWidget,
    );
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('stacks its parts at 200 % text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpTile(tester, birthday());

    expect(find.text('Alice Wonderland'), findsOneWidget);
    expect(stacked(tester), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reads a stacked row in the order of a single row', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpTile(tester, birthday());

    expect(stacked(tester), isTrue);
    // Le compte à rebours est au-dessus du nom, mais se lit après lui.
    expect(
      tester.getSemantics(find.text('Alice Wonderland')).label,
      'Amis, Famille\nAlice Wonderland\n24 octobre · 36 ans\nDans 12 jours',
    );
    semantics.dispose();
  });

  testWidgets('reads nothing before the name of a stacked row without groups', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpTile(tester, birthday(categories: const []));

    expect(stacked(tester), isTrue);
    expect(
      tester.getSemantics(find.text('Alice Wonderland')).label,
      'Alice Wonderland\n24 octobre · 36 ans\nDans 12 jours',
    );
    semantics.dispose();
  });

  // La police des tests est plus large que Outfit : 480 dp y valent la
  // largeur d'une ligne d'agenda sur un téléphone.
  testWidgets('keeps one row while the date fits on one line', (tester) async {
    await pumpTile(tester, birthday(), width: 480);

    expect(stacked(tester), isFalse);
  });

  testWidgets('keeps the same height whatever the length of the name', (
    tester,
  ) async {
    const long = Birthday(
      id: '2',
      name: 'Marie-Charlotte',
      surname: 'Delacroix-Fontaine de La Tour',
      date: BirthDate(year: 1990, month: 10, day: 24),
    );
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        Center(
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AgendaTile(birthday: birthday()),
                const AgendaTile(birthday: long),
              ],
            ),
          ),
        ),
        overrides: overrides(),
      );
      await tester.pumpAndSettle();
    });

    // Le nom long s'arrête sur « … » au lieu d'ajouter une ligne.
    final heights = [
      for (final tile in tester.elementList(find.byType(AgendaTile)))
        tile.size!.height,
    ];
    expect(heights.first, heights.last);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacks once the date no longer fits on one line', (
    tester,
  ) async {
    await pumpTile(tester, birthday(), width: 200);

    expect(find.text('24 octobre · 36 ans'), findsOneWidget);
    expect(stacked(tester), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gives every row the same shape, whatever its month', (
    tester,
  ) async {
    // À 420 dp, « 24 juin · 36 ans » tiendrait sur une ligne, pas la date la
    // plus longue de l'année : les deux lignes s'empilent ensemble.
    Birthday person(String id, String name, int month) => Birthday(
      id: id,
      name: name,
      surname: '',
      date: BirthDate(year: 1990, month: month, day: 24),
    );
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        Center(
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AgendaTile(birthday: person('1', 'June', 6)),
                AgendaTile(birthday: person('2', 'September', 9)),
              ],
            ),
          ),
        ),
        overrides: overrides(),
      );
      await tester.pumpAndSettle();
    });

    for (final name in ['June', 'September']) {
      final tile = find.widgetWithText(AgendaTile, name);
      final avatar = find.descendant(
        of: tile,
        matching: find.byType(AnKiAvatar),
      );
      expect(
        tester.getTopLeft(find.text(name)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(avatar).dy),
        reason: name,
      );
    }
  });
}
