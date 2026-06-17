import 'package:an_ki/features/birthday/data/models/category_model.dart';
import 'package:an_ki/features/birthday/data/repositories/category_repository.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/category_form_sheet.dart';
import 'package:an_ki/features/user/data/models/user_model.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/test_harness.dart';

class StubCategoryRepository implements CategoryRepository {
  StubCategoryRepository(this.categories);
  final List<BirthdayCategory> categories;

  @override
  Stream<List<BirthdayCategory>> watchCategories() => Stream.value(categories);

  @override
  Future<String> createCategory(BirthdayCategory category) async =>
      'new-cat-id';
}

void main() {
  final family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe1be);
  final friend = BirthdayCategory(id: 'fri', name: 'friend', icon: 0xe1bf);

  List<dynamic> overrides(
    FakeCategoryNotifier categoryNotifier, {
    List<BirthdayCategory> all = const [],
    List<String> userCategories = const [],
  }) => [
    categoryNotifierProvider.overrideWith(() => categoryNotifier),
    categoryRepositoryProvider.overrideWithValue(StubCategoryRepository(all)),
    userProvider.overrideWith(
      () => FakeUserNotifier(
        initialState: UserState(
          user: UserModel(
            id: 'u',
            name: 'A',
            surname: 'B',
            categories: userCategories,
            isDark: false,
            locale: 'fr',
          ),
        ),
      ),
    ),
  ];

  testWidgets('creates a custom category with a chosen icon', (tester) async {
    final categoryNotifier = FakeCategoryNotifier();
    await tester.pumpHarness(
      const CategoryFormSheet(),
      overrides: overrides(categoryNotifier, all: [family]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle catégorie'), findsOneWidget);

    // Pick a different icon from the grid.
    await tester.tap(find.byIcon(Icons.work_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Work');
    await tester.tap(find.text('Ajouter').last);
    await tester.pumpAndSettle();

    expect(categoryNotifier.createdNames, contains('Work'));
  });

  testWidgets('adds selected suggested categories', (tester) async {
    final categoryNotifier = FakeCategoryNotifier();
    await tester.pumpHarness(
      const CategoryFormSheet(),
      overrides: overrides(categoryNotifier, all: [family, friend]),
    );
    await tester.pumpAndSettle();

    // Select a suggested FilterChip, then toggle another one off and on.
    await tester.tap(find.widgetWithText(FilterChip, 'Ami'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Ami')); // deselect
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Famille'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter').last);
    await tester.pumpAndSettle();

    expect(categoryNotifier.addedToUser, isNotEmpty);
    expect(categoryNotifier.addedToUser.first, contains('fam'));
  });

  testWidgets('warns when nothing is selected or typed', (tester) async {
    final categoryNotifier = FakeCategoryNotifier();
    await tester.pumpHarness(
      const CategoryFormSheet(),
      overrides: overrides(categoryNotifier, all: [family]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajouter').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Veuillez sélectionner ou créer une catégorie'),
      findsOneWidget,
    );
    expect(categoryNotifier.createdNames, isEmpty);
    expect(categoryNotifier.addedToUser, isEmpty);
  });

  testWidgets('shows a message when no suggestions remain', (tester) async {
    final categoryNotifier = FakeCategoryNotifier();
    await tester.pumpHarness(
      const CategoryFormSheet(),
      overrides: overrides(
        categoryNotifier,
        all: [family],
        userCategories: const ['fam'],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucune autre catégorie suggérée'), findsOneWidget);
  });

  testWidgets('close button dismisses the sheet', (tester) async {
    final categoryNotifier = FakeCategoryNotifier();
    await tester.pumpHarness(
      const SizedBox(),
      home: Builder(
        builder:
            (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => CategoryFormSheet.show(context),
                  child: const Text('open'),
                ),
              ),
            ),
      ),
      overrides: overrides(categoryNotifier, all: [family]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle catégorie'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle catégorie'), findsNothing);
  });
}
