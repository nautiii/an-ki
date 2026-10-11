import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_editor.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/birthday/widgets/birthday_calendar.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/category_form_sheet.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

/// A birthday whose anniversary is [daysAhead] days from today.
Birthday _relative(
  int daysAhead, {
  required String id,
  required String name,
  required String surname,
}) {
  final today = DateTime.now();
  final target = DateTime(
    today.year,
    today.month,
    today.day,
  ).add(Duration(days: daysAhead));
  return Birthday(
    id: id,
    name: name,
    surname: surname,
    date: DateTime(1990, target.month, target.day),
  );
}

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

  testWidgets('invites to add the first birthday', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overrides(birthdays: const []),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vos anniversaires vivront ici'), findsOneWidget);
      expect(find.text('Prochain anniversaire'), findsNothing);
      expect(find.text('Aucun anniversaire trouvé.'), findsNothing);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Ajouter un anniversaire'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BirthdayFormSheet), findsOneWidget);
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

  testWidgets('shows skeletons while loading', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overrides(birthdays: const [], isLoading: true),
      );
      await tester.pump();

      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Vos anniversaires vivront ici'), findsNothing);
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

        await tester.tap(find.widgetWithText(ActionChip, 'Nouvelle catégorie'));
        await tester.pumpAndSettle();

        expect(find.byType(CategoryFormSheet), findsOneWidget);
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
        await tester.tap(find.byTooltip('Nouvelle catégorie'));
        await tester.pumpAndSettle();
        expect(find.byType(CategoryFormSheet), findsOneWidget);
      });
    });
  });

  // Anniversaires lus par le vrai provider depuis un dépôt factice :
  // suppression par glissement et ses échecs.
  group('birthdays from the repository', () {
    // The closest birthday is rendered in the "next birthday" card and excluded
    // from the scrollable list, so we always provide a second, farther one.
    final next = _relative(5, id: 'next', name: 'Alice', surname: 'Wonderland');
    final listed = _relative(40, id: 'listed', name: 'Bob', surname: 'Builder');

    List<dynamic> overridesWith(RecordingBirthdayRepository repository) => [
      currentUidProvider.overrideWithValue('fake-uid'),
      userProfileProvider.overrideWithValue(
        const AsyncData(
          UserProfile(
            id: 'fake-uid',
            name: 'A',
            surname: 'B',
            isDark: false,
            locale: 'fr',
          ),
        ),
      ),
      birthdayRepositoryProvider.overrideWithValue(repository),
      categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
    ];

    testWidgets('HomeScreen lists non-next birthdays', (tester) async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overridesWith(
          RecordingBirthdayRepository(initial: [next, listed]),
        ),
      );
      await tester.pumpAndSettle();

      // "Alice" appears in the next-birthday card, "Bob" in the list below.
      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('Bob Builder'), findsOneWidget);
    });

    testWidgets(
      'swiping a listed birthday asks for confirmation and deletes it',
      (tester) async {
        final repository = RecordingBirthdayRepository(initial: [next, listed]);

        await tester.pumpHarness(
          const HomeScreen(),
          overrides: overridesWith(repository),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bob Builder'), findsOneWidget);

        // Swipe the listed tile (start-to-end) to trigger the delete confirmation.
        await tester.drag(find.text('Bob Builder'), const Offset(600, 0));
        await tester.pumpAndSettle();

        expect(find.text('Supprimer l\'anniversaire'), findsOneWidget);

        await tester.tap(find.text('Supprimer'));
        await tester.pumpAndSettle();

        expect(repository.deleted, contains('listed'));
      },
    );

    testWidgets('a failed delete is announced once the tile is gone', (
      tester,
    ) async {
      final repository = RecordingBirthdayRepository(
        initial: [next, listed],
        failure: Exception('denied'),
      );

      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overridesWith(repository),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('Bob Builder'), const Offset(600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(
        find.text("Erreur lors de l'enregistrement de l'anniversaire"),
        findsOneWidget,
      );
    });

    testWidgets('cancelling the confirmation keeps the birthday', (
      tester,
    ) async {
      final repository = RecordingBirthdayRepository(initial: [next, listed]);

      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overridesWith(repository),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('Bob Builder'), const Offset(600, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(repository.deleted, isEmpty);
      expect(find.text('Bob Builder'), findsOneWidget);
    });

    testWidgets('screen readers delete through the tile action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final repository = RecordingBirthdayRepository(initial: [next, listed]);

      await tester.pumpHarness(
        const HomeScreen(),
        overrides: overridesWith(repository),
      );
      await tester.pumpAndSettle();

      tester.semantics.customAction(
        find.semantics.byLabel(RegExp('Bob Builder')),
        const CustomSemanticsAction(label: 'Supprimer'),
      );
      await tester.pumpAndSettle();
      expect(find.text("Supprimer l'anniversaire"), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(repository.deleted, ['listed']);
      expect(find.text("Anniversaire de Bob Builder supprimé"), findsOneWidget);
      semantics.dispose();
    });
  });
}
