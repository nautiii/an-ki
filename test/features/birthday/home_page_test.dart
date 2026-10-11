import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_editor.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/birthday/widgets/birthday_calendar.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';
import '../../support/test_harness.dart';

void main() {
  final now = DateTime.now();
  const family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe1be);

  Birthday onDay(int daysAhead, {required String id, String? cat}) {
    final target = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: daysAhead));
    return Birthday(
      id: id,
      name: 'Person$id',
      surname: 'X',
      date: DateTime(1990, target.month, target.day),
      categories: cat == null ? const [] : [cat],
    );
  }

  List<dynamic> overrides({
    required List<Birthday> birthdays,
    bool isLoading = false,
    List<String> userCategories = const [],
    List<BirthdayCategory> repoCategories = const [],
  }) => [
    currentUidProvider.overrideWithValue('fake-uid'),
    userProfileProvider.overrideWithValue(
      AsyncData(
        UserProfile(
          id: 'fake-uid',
          name: 'A',
          surname: 'B',
          categories: userCategories,
          isDark: false,
          locale: 'fr',
        ),
      ),
    ),
    birthdaysProvider.overrideWithValue(
      isLoading ? const AsyncLoading() : AsyncData(birthdays),
    ),
    categoryRepositoryProvider.overrideWithValue(
      RecordingCategoryRepository(repoCategories),
    ),
  ];

  testWidgets('shows the empty state when there are no other birthdays', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overrides(birthdays: [onDay(5, id: '1')]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aucun anniversaire trouvé.'), findsOneWidget);
    });
  });

  testWidgets('announces a failed category write', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: [
          ...overrides(birthdays: const []),
          userRepositoryProvider.overrideWithValue(
            RecordingUserRepository(failure: Exception('rules')),
          ),
        ],
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );

      await container.read(categoryEditorProvider.notifier).addToProfile([
        'fri',
      ]);
      await tester.pumpAndSettle();

      expect(
        find.text("Erreur lors de l'enregistrement de la catégorie"),
        findsOneWidget,
      );
    });
  });

  testWidgets('the settings button opens the settings route', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overrides(birthdays: const []),
        routes: {AppRoutes.settings: (_) => const Text('Settings route')},
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Settings route'), findsOneWidget);
    });
  });

  testWidgets('shows a loading indicator', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overrides(birthdays: const [], isLoading: true),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  testWidgets('lists the non-next birthdays', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overrides(
          birthdays: [
            onDay(5, id: '1'),
            onDay(40, id: '2'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Person2 X'), findsOneWidget);

      // Typing in the search bar updates the query provider.
      await tester.enterText(find.byType(TextField), 'Person2');
      await tester.pumpAndSettle();
      expect(find.text('Person2 X'), findsOneWidget);
    });
  });

  testWidgets('switches to the calendar view', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overrides(birthdays: [onDay(5, id: '1')]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.calendar_month_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(BirthdayCalendar), findsOneWidget);
    });
  });

  group('category filter bar', () {
    testWidgets('shows an add chip when the user has no categories', (
      tester,
    ) async {
      await mockNetworkImages(() async {
        await tester.pumpHarness(
          const HomeScreen(),
          overrides: overrides(birthdays: [onDay(5, id: '1')]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ActionChip, 'Ajouter'));
        await tester.pumpAndSettle();

        expect(find.text('Nouvelle catégorie'), findsOneWidget);
      });
    });

    testWidgets('lets the user filter by category', (tester) async {
      await mockNetworkImages(() async {
        await tester.pumpHarness(
          const HomeScreen(),
          overrides: overrides(
            birthdays: [
              onDay(5, id: '1'),
              onDay(40, id: '2', cat: 'fam'),
            ],
            userCategories: const ['fam'],
            repoCategories: [family],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ChoiceChip, 'Famille'));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        expect(container.read(birthdayCategoryFilterProvider), ['fam']);

        // Unselect again.
        await tester.tap(find.widgetWithText(ChoiceChip, 'Famille'));
        await tester.pumpAndSettle();
        expect(container.read(birthdayCategoryFilterProvider), isEmpty);

        // The trailing "+" chip opens the category form.
        await tester.tap(find.widgetWithIcon(ActionChip, Icons.add));
        await tester.pumpAndSettle();
        expect(find.text('Nouvelle catégorie'), findsOneWidget);
      });
    });
  });
}
