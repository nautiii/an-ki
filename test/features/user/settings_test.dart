import 'package:an_ki/features/user/screens/settings_screen.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/data/models/user_model.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import '../../support/fake_providers.dart';

void main() {
  testWidgets('SettingsScreen allows pseudo update', (tester) async {
    final userNotifier = FakeUserNotifier(
      initialState: UserState(
        user: const UserModel(
          id: '1',
          name: 'Quentin',
          surname: 'Maillard',
          pseudo: 'OldPseudo',
          isDark: false,
          locale: 'fr',
        ),
      ),
    );

    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: [
        authProvider.overrideWith(FakeAuthNotifier.new),
        userProvider.overrideWith(() => userNotifier),
        birthdayProvider.overrideWith(FakeBirthdayNotifier.new),
        categoryNotifierProvider.overrideWith(FakeCategoryNotifier.new),
        bookScannerProvider.overrideWith(FakeBookScannerNotifier.new),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('OldPseudo'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'NewPseudo');
    await tester.tap(find.text('Mettre à jour le pseudo'));
    await tester.pumpAndSettle();

    expect(userNotifier.state.user?.pseudo, 'NewPseudo');
    expect(find.text('Pseudo mis à jour avec succès !'), findsOneWidget);
  });

  testWidgets('SettingsScreen shows sign out dialog', (tester) async {
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: defaultTestOverrides,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();

    expect(find.text('Êtes-vous sûr de vouloir vous déconnecter ?'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
  });
}
