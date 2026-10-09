import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/user/domain/user_model.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import '../../support/fake_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'HomeScreen opens the create birthday page from the search bar add button',
    (WidgetTester tester) async {
      await tester.pumpHarness(
        const HomeScreen(),
        overrides: [
          authProvider.overrideWith(
            () => FakeAuthNotifier(initialState: AuthState(user: MockUser())),
          ),
          userProfileProvider.overrideWithValue(const AsyncData(null)),
          birthdayRepositoryProvider.overrideWithValue(
            RecordingBirthdayRepository(),
          ),
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
    final repository = RecordingBirthdayRepository();

    await tester.pumpHarness(
      const HomeScreen(),
      overrides: [
        authProvider.overrideWith(
          () => FakeAuthNotifier(initialState: AuthState(user: MockUser())),
        ),
        userProfileProvider.overrideWithValue(
          const AsyncData(
            UserModel(
              id: '1',
              name: 'Marie',
              surname: 'Martin',
              isDark: false,
              locale: 'fr',
            ),
          ),
        ),
        birthdayRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Thomas');
    await tester.enterText(find.byType(TextFormField).at(1), 'Leroy');

    await tester.tap(find.text('Ajouter').last);
    await tester.pumpAndSettle();

    expect(repository.created, hasLength(1));
    expect(repository.created.single.name, 'Thomas');
    expect(repository.created.single.surname, 'Leroy');
    expect(find.text('Nouvel anniversaire'), findsNothing);
  });
}
