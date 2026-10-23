import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
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
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

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
        UserProfile(
          id: 'fake-uid',
          name: 'A',
          surname: 'B',
          categories: ['fam', 'fri'],
          isDark: false,
          locale: 'fr',
        ),
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
  }) => mockNetworkImages(() async {
    await tester.pumpHarness(
      Center(
        child: SizedBox(
          width: 312,
          child: AgendaTile(birthday: birthday, highlight: highlight),
        ),
      ),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('shows who, when, how old and how soon', (tester) async {
    await pumpTile(tester, birthday());

    expect(find.text('Alice Wonderland'), findsOneWidget);
    expect(find.text('24 octobre · aura 36 ans'), findsOneWidget);
    expect(find.text('J-12'), findsOneWidget);
  });

  testWidgets('shows the date alone without a birth year', (tester) async {
    await pumpTile(tester, birthday(date: const BirthDate(month: 10, day: 24)));

    expect(find.text('24 octobre'), findsOneWidget);
    expect(find.textContaining('aura'), findsNothing);
    expect(find.text('J-12'), findsOneWidget);
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
    );

    expect(find.text('Souhaité'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Alice Wonderland')).label,
      contains('Souhaité'),
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
    expect(find.text('Souhaité'), findsNothing);

    // Souhaité hier : le vœu compte toujours, mais la ligne n'est plus celle
    // du jour.
    await pumpTile(
      tester,
      birthday(
        date: const BirthDate(year: 1990, month: 10, day: 11),
        wishedYears: const [2026],
      ),
    );
    expect(find.text('Souhaité'), findsNothing);
  });

  testWidgets('says tomorrow rather than J-1', (tester) async {
    await pumpTile(
      tester,
      birthday(date: const BirthDate(year: 1990, month: 10, day: 13)),
    );

    expect(find.text('Demain'), findsOneWidget);
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
    await pumpTile(tester, birthday(categories: const [], picture: _png));

    expect(
      tester.widget<AnKiAvatar>(find.byType(AnKiAvatar)).ringColors,
      isEmpty,
    );
  });

  testWidgets('reads the categories and offers deletion to TalkBack', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpTile(tester, birthday());

    expect(
      tester.getSemantics(find.text('Alice Wonderland')),
      isSemantics(
        label: 'Ami, Famille\nAlice Wonderland\n24 octobre · aura 36 ans\nJ-12',
        isButton: true,
        hasTapAction: true,
        customActions: [const CustomSemanticsAction(label: 'Supprimer')],
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('tapping opens the edit sheet', (tester) async {
    await pumpTile(tester, birthday());

    await tester.tap(find.text('Alice Wonderland'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier'), findsOneWidget);
  });

  testWidgets('stacks its parts at 200 % text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpTile(tester, birthday());

    expect(find.text('Alice Wonderland'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
