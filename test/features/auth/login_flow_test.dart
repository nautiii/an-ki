import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_providers.dart';

void main() {
  testWidgets('a failed e-mail sign-in is said once, by its page', (
    tester,
  ) async {
    await tester.pumpApp(
      auth: FakeAuthRepository(failure: AuthFailure.wrongPassword),
    );
    await tester.settleApp();
    await tester.tap(find.text("J'ai déjà un compte"));
    await tester.settleApp();
    await tester.tap(find.text('Continuer avec un e-mail'));
    await tester.settleApp();

    await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
    await tester.enterText(find.byType(TextField).at(1), 'mauvais');
    await tester.pump();
    await tester.tap(find.text('Se connecter').last);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    // Rien d'autre en file : l'accueil et le choix, dessous, se taisent.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
