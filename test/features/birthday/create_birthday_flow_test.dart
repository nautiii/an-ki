import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
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
          currentUidProvider.overrideWithValue('fake-uid'),
          userProfileProvider.overrideWithValue(
            const AsyncData(
              UserProfile(
                id: '1',
                name: 'Marie',
                surname: 'Martin',
                locale: 'fr',
              ),
            ),
          ),
          birthdayRepositoryProvider.overrideWithValue(
            RecordingBirthdayRepository(),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Ajouter un anniversaire'), findsOneWidget);

      await tester.tap(find.byTooltip('Ajouter un anniversaire'));
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
        currentUidProvider.overrideWithValue('fake-uid'),
        userProfileProvider.overrideWithValue(
          const AsyncData(
            UserProfile(
              id: '1',
              name: 'Marie',
              surname: 'Martin',
              locale: 'fr',
            ),
          ),
        ),
        birthdayRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ajouter un anniversaire'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Prénom et nom'),
      'Thomas Leroy',
    );
    await tester.enterText(
      find.widgetWithText(TextField, "Date d'anniversaire"),
      '2406',
    );
    await tester.pump();

    await tester.tap(find.text('Ajouter').last);
    await tester.pumpAndSettle();

    expect(repository.created, hasLength(1));
    expect(repository.created.single.name, 'Thomas');
    expect(repository.created.single.surname, 'Leroy');
    expect(repository.created.single.date, const BirthDate(month: 6, day: 24));
    expect(find.text('Nouvel anniversaire'), findsNothing);
  });
}
