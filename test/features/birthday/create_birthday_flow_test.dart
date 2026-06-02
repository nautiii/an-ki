import 'package:an_ki/data/models/user_model.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/home_page.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import '../../support/fake_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'HomePage opens the create birthday page from the search bar add button',
    (WidgetTester tester) async {
      final birthdayNotifierInstance = FakeBirthdayNotifier();

      await tester.pumpHarness(
        const HomePage(),
        overrides: [
          authProvider.overrideWith(
            () => FakeAuthNotifier(initialState: AuthState(user: MockUser())),
          ),
          userProvider.overrideWith(FakeUserNotifier.new),
          birthdayProvider.overrideWith(() => birthdayNotifierInstance),
          categoryNotifierProvider.overrideWith(FakeCategoryNotifier.new),
          bookScannerProvider.overrideWith(FakeBookScannerNotifier.new),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Nouvel anniversaire'), findsOneWidget);
    },
  );

  testWidgets('Create birthday flow submits a new birthday to the provider', (
    WidgetTester tester,
  ) async {
    final birthdayNotifierInstance = FakeBirthdayNotifier();

    await tester.pumpHarness(
      const HomePage(),
      overrides: [
        authProvider.overrideWith(
          () => FakeAuthNotifier(initialState: AuthState(user: MockUser())),
        ),
        userProvider.overrideWith(
          () => FakeUserNotifier(
            initialState: UserState(
              user: const UserModel(
                id: '1',
                name: 'Marie',
                surname: 'Martin',
                isDark: false,
                locale: 'fr',
              ),
            ),
          ),
        ),
        birthdayProvider.overrideWith(() => birthdayNotifierInstance),
        categoryNotifierProvider.overrideWith(FakeCategoryNotifier.new),
        bookScannerProvider.overrideWith(FakeBookScannerNotifier.new),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Thomas');
    await tester.enterText(find.byType(TextFormField).at(1), 'Leroy');

    await tester.tap(find.text('Ajouter').last);
    await tester.pumpAndSettle();

    expect(birthdayNotifierInstance.createdInputs, hasLength(1));
    expect(birthdayNotifierInstance.createdInputs.single.name, 'Thomas');
    expect(birthdayNotifierInstance.createdInputs.single.surname, 'Leroy');
    expect(find.text('Nouvel anniversaire'), findsNothing);
  });
}
