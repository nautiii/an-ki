import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/data/models/category_model.dart';
import 'package:an_ki/features/birthday/data/repositories/category_repository.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/birthday/widgets/birthday_calendar.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:an_ki/features/user/data/models/user_model.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';
import '../../support/test_harness.dart';

class StubCategoryRepository implements CategoryRepository {
  StubCategoryRepository(this.categories);
  final List<BirthdayCategory> categories;

  @override
  Stream<List<BirthdayCategory>> watchCategories() => Stream.value(categories);

  @override
  Future<String> createCategory(BirthdayCategory category) async => 'x';
}

void main() {
  final now = DateTime.now();
  final family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe1be);

  BirthdayModel onDay(int daysAhead, {required String id, String? cat}) {
    final target = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: daysAhead));
    return BirthdayModel(
      id: id,
      uid: 'fake-uid',
      name: 'Person$id',
      surname: 'X',
      date: DateTime(1990, target.month, target.day),
      categories: cat == null ? const [] : [cat],
    );
  }

  List<dynamic> overrides({
    required List<BirthdayModel> birthdays,
    bool isLoading = false,
    List<String> userCategories = const [],
    List<BirthdayCategory> repoCategories = const [],
  }) => [
    authProvider.overrideWith(
      () => FakeAuthNotifier(initialState: AuthState(user: MockUser())),
    ),
    userProvider.overrideWith(
      () => FakeUserNotifier(
        initialState: UserState(
          user: UserModel(
            id: 'fake-uid',
            name: 'A',
            surname: 'B',
            categories: userCategories,
            isDark: false,
            locale: 'fr',
          ),
        ),
      ),
    ),
    birthdayProvider.overrideWith(
      () => FakeBirthdayNotifier(
        initialState: BirthdayState(birthdays: birthdays, isLoading: isLoading),
      ),
    ),
    categoryNotifierProvider.overrideWith(FakeCategoryNotifier.new),
    categoryRepositoryProvider.overrideWithValue(
      StubCategoryRepository(repoCategories),
    ),
    bookScannerProvider.overrideWith(FakeBookScannerNotifier.new),
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
