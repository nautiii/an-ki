import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/test_harness.dart';

void main() {
  testWidgets('LoginScreen allows signing in', (tester) async {
    final repository = FakeAuthRepository();

    await tester.pumpHarness(
      const LoginScreen(),
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        // La connexion regarde si l'empreinte de l'appareil est la sienne.
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
      ],
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.pump();

    await tester.tap(find.text('Se connecter').last);
    await tester.pumpAndSettle();

    expect(repository.calls, ['signInWithEmail']);
    expect(repository.currentUser?.uid, 'fake-uid');
  });
}
