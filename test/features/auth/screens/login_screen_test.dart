import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
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

      expect(
        find.text("Quelque chose s'est mal passé. Réessayez dans un instant."),
        findsOneWidget,
      );
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

    group('forgotten password', () {
      final forgot = find.text('Mot de passe oublié\u202f?');
      final sent = find.text('E\u2011mail envoyé à lea@exemple.fr');
      const needsEmail = 'Saisissez votre e\u2011mail pour recevoir le lien';

      Future<FakeAuthRepository> pumpLogin(
        WidgetTester tester, {
        Exception? resetFailure,
      }) async {
        final repository = FakeAuthRepository(resetFailure: resetFailure);
        await tester.pumpHarness(
          const LoginScreen(),
          overrides: authOverrides(repository),
        );
        await tester.pumpAndSettle();
        return repository;
      }

      testWidgets('sends the link to the typed address, in the app language', (
        tester,
      ) async {
        final repository = await pumpLogin(tester);

        await tester.enterText(
          find.byType(TextField).at(0),
          ' lea@exemple.fr ',
        );
        await tester.tap(forgot);
        await tester.pumpAndSettle();

        expect(repository.passwordResets, [('lea@exemple.fr', 'fr')]);
        expect(sent, findsOneWidget);
        // Le clavier rangé laisse voir la confirmation.
        expect(
          FocusManager.instance.primaryFocus?.context?.widget,
          isNot(isA<EditableText>()),
        );
        expect(
          find.text(
            'Ouvrez son lien pour choisir un nouveau mot de passe. Rien '
            "reçu\u202f? Vérifiez l'adresse et vos courriers indésirables.",
          ),
          findsOneWidget,
        );
        // Ni connexion, ni « Se connecter » qui tourne.
        expect(repository.calls, ['sendPasswordReset']);
      });

      testWidgets('without an address, says what is missing in the field', (
        tester,
      ) async {
        final repository = await pumpLogin(tester);

        await tester.tap(forgot);
        await tester.pumpAndSettle();

        expect(find.text(needsEmail), findsOneWidget);
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: find.byType(TextField).at(0),
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          isTrue,
        );
        expect(repository.calls, isEmpty);

        // Une frappe efface la consigne.
        await tester.enterText(find.byType(TextField).at(0), 'l');
        await tester.pump();
        expect(find.text(needsEmail), findsNothing);
      });

      testWidgets('sends it again to a corrected address', (tester) async {
        final repository = await pumpLogin(tester);
        await tester.enterText(find.byType(TextField).at(0), 'lea@exmple.fr');
        await tester.tap(forgot);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).at(0), 'lea@exemple.fr');
        await tester.tap(find.text('Renvoyer le lien'));
        await tester.pumpAndSettle();

        expect(repository.passwordResets, [
          ('lea@exmple.fr', 'fr'),
          ('lea@exemple.fr', 'fr'),
        ]);
        expect(sent, findsOneWidget);
      });

      testWidgets('says why the link could not leave', (tester) async {
        await pumpLogin(tester, resetFailure: AuthFailure.network);
        await tester.enterText(find.byType(TextField).at(0), 'lea@exemple.fr');

        await tester.tap(forgot);
        await tester.pumpAndSettle();

        expect(
          find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
          findsOneWidget,
        );
        expect(sent, findsNothing);
        expect(forgot, findsOneWidget);
      });

      testWidgets('keeps labelled 48 dp targets once sent', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpLogin(tester);
        await tester.enterText(find.byType(TextField).at(0), 'lea@exemple.fr');
        await tester.tap(forgot);
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    });

    testWidgets('says which sign-in it is, in a header', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpHarness(const LoginScreen());
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Connexion par e‑mail')),
        isSemantics(isHeader: true),
      );
      expect(find.text('Vos anniversaires vous attendent.'), findsOneWidget);
      expect(find.text('E‑mail'), findsOneWidget);
      semantics.dispose();
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
