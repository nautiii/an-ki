import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/providers/sign_up_names_provider.dart';
import 'package:an_ki/features/auth/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/auth_overrides.dart';
import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  group('SignUpScreen', () {
    testWidgets('shows an error when passwords do not match', (tester) async {
      await tester.pumpHarness(const SignUpScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'John');
      await tester.enterText(find.byType(TextField).at(1), 'Doe');
      await tester.enterText(find.byType(TextField).at(2), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(3), 'secret1');
      await tester.enterText(find.byType(TextField).at(4), 'secret2');

      await tester.tap(find.text("S'inscrire").last);
      await tester.pumpAndSettle();

      expect(
        find.text('Les mots de passe ne correspondent pas'),
        findsOneWidget,
      );
    });

    testWidgets('keeps the typed names for the profile on success', (
      tester,
    ) async {
      await tester.pumpHarness(
        const SignUpScreen(),
        overrides: authOverrides(FakeAuthRepository()),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SignUpScreen)),
      );

      await tester.enterText(find.byType(TextField).at(0), 'John');
      await tester.enterText(find.byType(TextField).at(1), 'Doe');
      await tester.enterText(find.byType(TextField).at(2), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(3), 'secret');
      await tester.enterText(find.byType(TextField).at(4), 'secret');

      await tester.tap(find.text("S'inscrire").last);
      await tester.pumpAndSettle();

      // app/bootstrap créera le profil avec ces noms tels que saisis.
      expect(container.read(signUpNamesProvider), (
        name: 'John',
        surname: 'Doe',
      ));
    });

    testWidgets('shows an error SnackBar on failure', (tester) async {
      await tester.pumpHarness(
        const SignUpScreen(),
        overrides: failingAuthOverrides(),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SignUpScreen)),
      );

      await tester.enterText(find.byType(TextField).at(0), 'John');
      await tester.enterText(find.byType(TextField).at(1), 'Doe');
      await tester.enterText(find.byType(TextField).at(2), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(3), 'secret');
      await tester.enterText(find.byType(TextField).at(4), 'secret');

      await tester.tap(find.text("S'inscrire").last);
      await tester.pumpAndSettle();

      expect(find.text('Une erreur est survenue.'), findsOneWidget);
      // Inscription ratée : rien ne doit rester pour une connexion suivante.
      expect(container.read(signUpNamesProvider), isNull);
    });

    testWidgets('toggles both password fields visibility', (tester) async {
      await tester.pumpHarness(const SignUpScreen());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.visibility_off_outlined).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Toggle the confirm-password field too.
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
    });

    testWidgets('does nothing when mandatory fields are empty', (tester) async {
      final repository = FakeAuthRepository();
      await tester.pumpHarness(
        const SignUpScreen(),
        overrides: authOverrides(repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("S'inscrire").last);
      await tester.pumpAndSettle();

      expect(repository.calls, isEmpty);
    });

    testWidgets('navigates to the login route', (tester) async {
      await tester.pumpHarness(
        const SignUpScreen(),
        routes: {
          AppRoutes.login: (_) => const Scaffold(body: Text('Login Route')),
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Login Route'), findsOneWidget);
    });

    testWidgets('back button pops the page', (tester) async {
      await tester.pumpHarness(
        const SignUpScreen(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('disables inputs while loading', (tester) async {
      await tester.pumpHarness(
        const SignUpScreen(),
        overrides: loadingAuthOverrides(),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
