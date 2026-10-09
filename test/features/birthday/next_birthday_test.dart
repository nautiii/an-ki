import 'dart:convert';
import 'dart:typed_data';

import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_model.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/next_birthday.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';
import '../../support/test_harness.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  final now = DateTime.now();

  BirthdayModel relative(int daysAhead, {String id = '1', Uint8List? picture}) {
    final target = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: daysAhead));
    return BirthdayModel(
      id: id,
      name: 'Alice',
      surname: 'Wonderland',
      date: DateTime(1990, target.month, target.day),
      picture: picture,
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required List<BirthdayModel> birthdays,
    bool isLoading = false,
  }) async {
    await tester.pumpHarness(
      const NextBirthdayCard(),
      overrides: [
        birthdaysProvider.overrideWithValue(
          isLoading ? const AsyncLoading() : AsyncData(birthdays),
        ),
        authProvider.overrideWith(
          () => FakeAuthNotifier(initialState: AuthState(user: MockUser())),
        ),
        userProfileProvider.overrideWithValue(const AsyncData(null)),
        categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
      ],
    );
  }

  testWidgets('shows a placeholder when there is no birthday', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: const []);
      await tester.pumpAndSettle();

      expect(find.text('Aucun anniversaire'), findsOneWidget);
    });
  });

  testWidgets('shows a loading indicator', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: const [], isLoading: true);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  testWidgets('labels a birthday happening today', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(0, picture: _png)]);
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text("AUJOURD'HUI 🎉"), findsOneWidget);
    });
  });

  testWidgets('labels a birthday happening tomorrow', (tester) async {
    await mockNetworkImages(() async {
      await pumpCard(tester, birthdays: [relative(1)]);
      await tester.pumpAndSettle();

      expect(find.text('DEMAIN'), findsOneWidget);
    });
  });

  testWidgets('shows page indicators for multiple same-day birthdays', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pumpCard(
        tester,
        birthdays: [
          relative(0),
          relative(0, id: '2'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);

      // Swipe to the next page to trigger onPageChanged.
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
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
}
