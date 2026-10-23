import 'package:an_ki/core/routing/app_routes.dart';
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
        routes: {
          AppRoutes.signup: (_) => const Scaffold(body: Text('SignUp Route')),
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();

      expect(find.text('SignUp Route'), findsOneWidget);
    });

    testWidgets('shows the whole form at once, with no intro to wait for', (
      tester,
    ) async {
      await tester.pumpHarness(const LoginScreen());

      // Une seule image : une intro décalée laisserait ses minuteurs en
      // attente, et le test échouerait.
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Se connecter'), findsOneWidget);
    });

    testWidgets('keeps its label and disables the form while signing in', (
      tester,
    ) async {
      await tester.pumpHarness(
        const LoginScreen(),
        overrides: loadingAuthOverrides(),
      );
      // Pas de pumpAndSettle : l'indicateur tourne tant que dure l'attente.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final signIn = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Se connecter'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(signIn.onPressed, isNull);
      final signUp = tester.widget<TextButton>(
        find.ancestor(
          of: find.text("S'inscrire"),
          matching: find.byType(TextButton),
        ),
      );
      expect(signUp.onPressed, isNull);
    });

    testWidgets('scrolls instead of overflowing on a small phone at 200 %', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpHarness(const LoginScreen());
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text("S'inscrire"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text("S'inscrire"), findsOneWidget);
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

      // Le retour standard, nommé pour TalkBack.
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
    });
  });
}
