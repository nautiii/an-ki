import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import '../../support/fake_providers.dart';

void main() {
  testWidgets('LoginScreen allows signing in', (tester) async {
    final authNotifier = FakeAuthNotifier();

    await tester.pumpHarness(
      const LoginScreen(),
      overrides: [authProvider.overrideWith(() => authNotifier)],
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'test@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');

    await tester.tap(find.text('Se connecter').last);
    await tester.pumpAndSettle();

    expect(authNotifier.state.user, isNotNull);
    expect(authNotifier.state.user?.uid, 'fake-uid');
  });
}
