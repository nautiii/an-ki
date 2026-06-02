import 'package:an_ki/core/app_initializer.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
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
      ],
    );

    await tester.pump(); 

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    userNotifierInstance.completePendingLoad();
    await tester.pumpAndSettle();

    expect(find.text('Child ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

class TestChild extends StatelessWidget {
  const TestChild({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Child ready')));
  }
}
