import 'package:an_ki/features/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/auth_overrides.dart';
import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('signs in successfully', (tester) async {
      final repository = FakeAuthRepository();
      await tester.pumpHarness(
        const LoginScreen(),
        overrides: authOverrides(repository),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.tap(find.text('Se connecter').last);
      await tester.pumpAndSettle();

      expect(repository.calls, ['signInWithEmail']);
      expect(repository.currentUser, isNotNull);
    });

    testWidgets('does nothing when fields are empty', (tester) async {
      final repository = FakeAuthRepository();
      await tester.pumpHarness(
        const LoginScreen(),
        overrides: authOverrides(repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se connecter').last);
      await tester.pumpAndSettle();

      expect(repository.calls, isEmpty);
    });

    testWidgets('shows an error SnackBar on failure', (tester) async {
      await tester.pumpHarness(
        const LoginScreen(),
        overrides: failingAuthOverrides(),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(1), 'bad');
      await tester.tap(find.text('Se connecter').last);
      await tester.pumpAndSettle();

      expect(find.text('Une erreur est survenue.'), findsOneWidget);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpHarness(const LoginScreen());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('forgot-password button is tappable', (tester) async {
      await tester.pumpHarness(const LoginScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();
    });

    testWidgets('navigates to the signup route', (tester) async {
      await tester.pumpHarness(
        const LoginScreen(),
        routes: {'/signup': (_) => const Scaffold(body: Text('SignUp Route'))},
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();

      expect(find.text('SignUp Route'), findsOneWidget);
    });

    testWidgets('disables inputs and shows a spinner while loading', (
      tester,
    ) async {
      await tester.pumpHarness(
        const LoginScreen(),
        overrides: loadingAuthOverrides(),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('back button pops the page', (tester) async {
      await tester.pumpHarness(
        const SizedBox(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
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
  });
}
