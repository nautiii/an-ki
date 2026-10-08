import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/models/birthday_model.dart';
import 'package:an_ki/features/birthday/data/models/category_model.dart';
import 'package:an_ki/features/birthday/data/repositories/category_repository.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/network_image_mock.dart';
import '../../support/test_harness.dart';

// 1x1 transparent PNG.
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

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

  BirthdayModel onDay(int day, {String id = '1', String? picture}) =>
      BirthdayModel(
        id: id,
        uid: 'u',
        name: 'Alice',
        surname: 'Wonderland',
        date: DateTime(1990, now.month, day),
        categories: const ['fam'],
        picture: picture,
      );

  Future<void> pumpCalendar(
    WidgetTester tester, {
    required List<BirthdayModel> birthdays,
  }) async {
    await tester.pumpHarness(
      const BirthdayCalendar(),
      overrides: [
        birthdaysProvider.overrideWithValue(AsyncData(birthdays)),
        currentUidProvider.overrideWithValue('u1'),
        categoryRepositoryProvider.overrideWithValue(
          StubCategoryRepository([family]),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the grid and navigates between months', (tester) async {
    await mockNetworkImages(() async {
      await pumpCalendar(tester, birthdays: [onDay(15)]);

      expect(find.byType(GridView), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
    });
  });

  testWidgets('tapping a day with birthdays opens the detail sheet', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pumpCalendar(tester, birthdays: [onDay(15, picture: _pngBase64)]);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
    });
  });

  testWidgets('day sheet lists multiple birthdays with a separator', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pumpCalendar(
        tester,
        birthdays: [
          onDay(15, picture: _pngBase64),
          onDay(15, id: '2'),
        ],
      );

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);
      expect(find.byIcon(Icons.cake_rounded), findsOneWidget);
    });
  });
}
