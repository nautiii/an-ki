import 'package:an_ki/features/auth/auth_choice_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import '../../support/fake_providers.dart';

void main() {
  testWidgets('AuthChoicePage shows all auth options', (tester) async {
    await tester.pumpHarness(
      const AuthChoicePage(),
      overrides: defaultTestOverrides,
    );
    await tester.pumpAndSettle();

    expect(find.text('Connexion Google'), findsOneWidget);
    expect(find.text('Connexion Email'), findsOneWidget);
    expect(find.text('Continuer sans compte'), findsOneWidget);
    expect(find.text("S'inscrire"), findsOneWidget);
  });

  testWidgets('Navigation to LoginPage', (tester) async {
    await tester.pumpHarness(
      const AuthChoicePage(),
      overrides: defaultTestOverrides,
      routes: {
        '/login': (context) => const Scaffold(body: Text('Login Page')),
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connexion Email'));
    await tester.pumpAndSettle();

    expect(find.text('Login Page'), findsOneWidget);
  });
}
