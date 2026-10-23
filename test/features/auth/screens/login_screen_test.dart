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
      await tester.pump();
      await tester.tap(find.text('Se connecter').last);
      await tester.pumpAndSettle();

      expect(repository.calls, ['signInWithEmail']);
      expect(repository.currentUser, isNotNull);
    });

    testWidgets('waits for both fields before « Se connecter »', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      await tester.pumpHarness(
        const LoginScreen(),
        overrides: authOverrides(repository),
      );
      await tester.pumpAndSettle();
      VoidCallback? signIn() => tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Se connecter'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed;

      expect(signIn(), isNull);
      await tester.tap(find.text('Se connecter'));
      await tester.enterText(find.byType(TextField).at(0), '  ');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.pump();
      // Des espaces ne font pas une adresse.
      expect(signIn(), isNull);

      await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
      await tester.pump();
      expect(signIn(), isNotNull);
      expect(repository.calls, isEmpty);
    });

    testWidgets('« Suivant » goes to the password, « OK » signs in', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      await tester.pumpHarness(
        const LoginScreen(),
        overrides: authOverrides(repository),
      );
      await tester.pumpAndSettle();
      bool hasFocus(int field) => tester
          .widget<EditableText>(
            find.descendant(
              of: find.byType(TextField).at(field),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus;

      await tester.enterText(find.byType(TextField).at(0), ' a@b.com ');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(hasFocus(1), isTrue);

      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(repository.calls, ['signInWithEmail']);
    });

    testWidgets('fills both fields from the password manager', (tester) async {
      await tester.pumpHarness(const LoginScreen());
      await tester.pumpAndSettle();
      final fields = tester.widgetList<TextField>(find.byType(TextField));

      expect(find.byType(AutofillGroup), findsOneWidget);
      expect(fields.map((field) => field.autofillHints), [
        [AutofillHints.email],
        [AutofillHints.password],
      ]);
      expect(fields.first.keyboardType, TextInputType.emailAddress);
    });

    testWidgets('meets tap target and label guidelines', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpHarness(const LoginScreen());
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('shows an error SnackBar on failure', (tester) async {
      await tester.pumpHarness(
        const LoginScreen(),
        overrides: failingAuthOverrides(),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(1), 'bad');
      await tester.pump();
      await tester.tap(find.text('Se connecter').last);
      await tester.pumpAndSettle();

      expect(find.text('Une erreur est survenue.'), findsOneWidget);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpHarness(const LoginScreen());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      await tester.tap(find.byTooltip('Afficher le mot de passe'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byTooltip('Masquer le mot de passe'), findsOneWidget);
    });

    testWidgets('forgot-password button is tappable', (tester) async {
      await tester.pumpHarness(const LoginScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();
    });

    testWidgets('sets its questions in French typography', (tester) async {
      await tester.pumpHarness(const LoginScreen());
      await tester.pumpAndSettle();

      // Espace fine insécable avant « ? », rien après.
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
      expect(find.text('Pas encore de compte ?'), findsOneWidget);
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
