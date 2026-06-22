import 'package:an_ki/app/bootstrap/app_initializer.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/features/user/data/repositories/user_repository.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as fam;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';
import 'support/fake_providers.dart';

void main() {
  testWidgets('AppInitializer shows child when user is loaded', (
    WidgetTester tester,
  ) async {
    final userNotifierInstance = FakeUserNotifier();
    userNotifierInstance.preparePendingLoad();

    await tester.pumpHarness(
      const AppInitializer(child: TestChild()),
      overrides: [
        authProvider.overrideWith(
          () => FakeAuthNotifier(initialState: AuthState(user: MockUser())),
        ),
        userProvider.overrideWith(() => userNotifierInstance),
        birthdayProvider.overrideWith(FakeBirthdayNotifier.new),
        bookScannerProvider.overrideWith(FakeBookScannerNotifier.new),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    userNotifierInstance.completePendingLoad();
    await tester.pumpAndSettle();

    expect(find.text('Child ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('creates a guest user for an anonymous account without a name', (
    tester,
  ) async {
    final userNotifier = FakeUserNotifier(defaultLoadedUser: null);

    await tester.pumpHarness(
      const AppInitializer(child: TestChild()),
      overrides: [
        authProvider.overrideWith(
          () => FakeAuthNotifier(
            initialState: AuthState(
              user: fam.MockUser(isAnonymous: true, displayName: ''),
            ),
          ),
        ),
        userProvider.overrideWith(() => userNotifier),
        birthdayProvider.overrideWith(FakeBirthdayNotifier.new),
        bookScannerProvider.overrideWith(FakeBookScannerNotifier.new),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );
    await tester.pumpAndSettle();

    expect(userNotifier.state.user, isNotNull);
    expect(find.text('Child ready'), findsOneWidget);
  });

  testWidgets('re-initializes when the authenticated uid changes', (
    tester,
  ) async {
    final authNotifier = FakeAuthNotifier(initialState: AuthState());

    await tester.pumpHarness(
      const AppInitializer(child: TestChild()),
      overrides: [
        authProvider.overrideWith(() => authNotifier),
        userProvider.overrideWith(FakeUserNotifier.new),
        birthdayProvider.overrideWith(FakeBirthdayNotifier.new),
        bookScannerProvider.overrideWith(FakeBookScannerNotifier.new),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );
    await tester.pumpAndSettle();

    // Signing in changes the uid, which the listener reacts to.
    final l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    await authNotifier.signInAnonymously(l10n);
    await tester.pumpAndSettle();

    expect(find.text('Child ready'), findsOneWidget);
  });
}

class TestChild extends StatelessWidget {
  const TestChild({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Child ready')));
  }
}
