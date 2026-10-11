import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/widgets/category_form_sheet.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  const family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe1be);
  const friend = BirthdayCategory(id: 'fri', name: 'friend', icon: 0xe1bf);

  late RecordingCategoryRepository categories;
  late RecordingUserRepository users;

  List<dynamic> overrides({
    List<BirthdayCategory> all = const [],
    List<String> userCategories = const [],
  }) {
    final profile = UserProfile(
      id: 'u',
      name: 'A',
      surname: 'B',
      categories: userCategories,
      isDark: false,
      locale: 'fr',
    );
    categories = RecordingCategoryRepository(all);
    users = RecordingUserRepository(stored: profile);
    return [
      categoryRepositoryProvider.overrideWithValue(categories),
      userRepositoryProvider.overrideWithValue(users),
      currentUidProvider.overrideWithValue('u'),
      userProfileProvider.overrideWithValue(AsyncData(profile)),
    ];
  }

  testWidgets('creates a custom category with a chosen icon', (tester) async {
    await tester.pumpHarness(
      const CategoryFormSheet(),
      overrides: overrides(all: [family]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle catégorie'), findsOneWidget);

    // Pick a different icon from the grid.
    await tester.tap(find.byIcon(Icons.work_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Work');
    await tester.tap(find.text('Ajouter').last);
    await tester.pumpAndSettle();

    expect(categories.created.single.name, 'Work');
    expect(categories.created.single.icon, Icons.work_rounded.codePoint);
    expect(users.stored?.categories, contains('new-cat-1'));
  });

  testWidgets('adds selected suggested categories', (tester) async {
    await tester.pumpHarness(
      const CategoryFormSheet(),
      overrides: overrides(all: [family, friend]),
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

    expect(users.stored?.categories, ['fam']);
    expect(categories.created, isEmpty);
  });

  testWidgets('warns when nothing is selected or typed', (tester) async {
    await tester.pumpHarness(
      const CategoryFormSheet(),
      overrides: overrides(all: [family]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajouter').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Veuillez sélectionner ou créer une catégorie'),
      findsOneWidget,
    );
    expect(categories.created, isEmpty);
    expect(users.updated, isEmpty);
  });

  testWidgets('shows a message when no suggestions remain', (tester) async {
    await tester.pumpHarness(
      const CategoryFormSheet(),
      overrides: overrides(all: [family], userCategories: const ['fam']),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucune autre catégorie suggérée'), findsOneWidget);
  });

  testWidgets('close button dismisses the sheet', (tester) async {
    await tester.pumpHarness(
      const SizedBox(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => CategoryFormSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      overrides: overrides(all: [family]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle catégorie'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle catégorie'), findsNothing);
  });

  testWidgets('names each icon and its selection for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(
      const CategoryFormSheet(),
      overrides: overrides(all: [family]),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Icône 1')),
      isSemantics(isButton: true, isSelected: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Icône 3')),
      isSemantics(isSelected: false),
    );

    // La sélection suit le toucher, lu aussi par TalkBack.
    await tester.tap(find.byIcon(Icons.work_rounded));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Icône 3')),
      isSemantics(isSelected: true),
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
