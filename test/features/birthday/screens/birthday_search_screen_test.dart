import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/screens/birthday_search_screen.dart';
import 'package:an_ki/features/birthday/widgets/agenda_tile.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/category_form_sheet.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  final today = DateTime(2026, 10, 12);
  const family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe1be);

  Birthday person(String id, String name, int month, [List<String>? cats]) =>
      Birthday(
        id: id,
        name: name,
        surname: 'Martin',
        date: BirthDate.fromDate(DateTime(1990, month, 20)),
        categories: cats ?? const [],
      );

  final lea = person('1', 'Léa', 10, ['fam']);
  final hugo = person('2', 'Hugo', 12);

  Future<void> pumpSearch(WidgetTester tester) async {
    await tester.pumpHarness(
      const BirthdaySearchScreen(),
      overrides: [
        clockProvider.overrideWithValue(() => today),
        currentUidProvider.overrideWithValue('fake-uid'),
        userProfileProvider.overrideWithValue(
          const AsyncData(
            UserProfile(
              id: 'fake-uid',
              name: 'A',
              surname: 'B',
              categories: ['fam'],
              isDark: false,
              locale: 'fr',
            ),
          ),
        ),
        birthdaysProvider.overrideWithValue(AsyncData([hugo, lea])),
        birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
        categoryRepositoryProvider.overrideWithValue(
          RecordingCategoryRepository([family]),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  List<String> listedNames(WidgetTester tester) => [
    for (final tile in tester.widgetList<AgendaTile>(find.byType(AgendaTile)))
      tile.birthday.name,
  ];

  testWidgets('lists everyone, the closest first', (tester) async {
    await pumpSearch(tester);

    expect(listedNames(tester), ['Léa', 'Hugo']);
  });

  testWidgets('narrows by name and clears in one tap', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'hug');
    await tester.pumpAndSettle();
    expect(listedNames(tester), ['Hugo']);

    await tester.tap(find.byTooltip('Effacer la recherche'));
    await tester.pumpAndSettle();
    expect(listedNames(tester), ['Léa', 'Hugo']);
    expect(find.byTooltip('Effacer la recherche'), findsNothing);
  });

  testWidgets('filters by category, then clears the filters', (tester) async {
    await pumpSearch(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Famille'));
    await tester.pumpAndSettle();
    expect(listedNames(tester), ['Léa']);

    await tester.enterText(find.byType(TextField), 'hugo');
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat pour « hugo »'), findsOneWidget);

    await tester.tap(find.text('Effacer les filtres'));
    await tester.pumpAndSettle();
    expect(listedNames(tester), ['Hugo']);
  });

  testWidgets('offers to add the person nobody found', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'Rose Dupont');
    await tester.pumpAndSettle();
    expect(find.text('Effacer les filtres'), findsNothing);

    await tester.tap(find.text('Ajouter « Rose Dupont »'));
    await tester.pumpAndSettle();

    // Le nom cherché pré-remplit le champ unique de la feuille.
    expect(
      find.descendant(
        of: find.byType(BirthdayFormSheet),
        matching: find.widgetWithText(TextField, 'Rose Dupont'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('creates a category from the filter row', (tester) async {
    await pumpSearch(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'Nouvelle catégorie'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryFormSheet), findsOneWidget);
  });

  testWidgets('meets tap target and label guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSearch(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
