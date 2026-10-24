import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/providers/sign_up_names_provider.dart';
import 'package:an_ki/features/auth/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/auth_overrides.dart';
import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

const _mismatch = 'Les mots de passe ne correspondent pas';

/// Bouton « S'inscrire » : null tant qu'il est désactivé.
VoidCallback? _signUp(WidgetTester tester) => tester
    .widget<FilledButton>(
      find.ancestor(
        of: find.text("S'inscrire"),
        matching: find.byType(FilledButton),
      ),
    )
    .onPressed;

Future<void> _fill(WidgetTester tester, List<String> values) async {
  for (final (index, value) in values.indexed) {
    await tester.enterText(find.byType(TextField).at(index), value);
  }
  await tester.pump();
}

void main() {
  group('SignUpScreen', () {
    testWidgets('says under the confirmation when it differs', (tester) async {
      await tester.pumpHarness(const SignUpScreen());
      await tester.pumpAndSettle();

      await _fill(tester, ['John', 'Doe', 'a@b.com', 'secret1', 'secret2']);

      final confirmation = tester.widget<TextField>(
        find.byType(TextField).at(4),
      );
      expect(confirmation.decoration?.errorText, _mismatch);
      expect(find.text(_mismatch), findsOneWidget);
      expect(_signUp(tester), isNull);
    });

    testWidgets('waits for the end of a right confirmation', (tester) async {
      await tester.pumpHarness(const SignUpScreen());
      await tester.pumpAndSettle();

      await _fill(tester, ['John', 'Doe', 'a@b.com', 'secret', 'sec']);
      // Juste mais inachevée, pendant la frappe : rien à dire.
      expect(find.text(_mismatch), findsNothing);
      expect(_signUp(tester), isNull);

      // Quittée inachevée, elle diffère.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.text(_mismatch), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(4), 'secret');
      await tester.pump();
      expect(find.text(_mismatch), findsNothing);
      expect(_signUp(tester), isNotNull);
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
      await tester.pump();

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
      await tester.pump();

      await tester.tap(find.text("S'inscrire").last);
      await tester.pumpAndSettle();

      expect(
        find.text("Quelque chose s'est mal passé. Réessayez dans un instant."),
        findsOneWidget,
      );
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

    testWidgets('waits for a complete form before « S\'inscrire »', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      await tester.pumpHarness(
        const SignUpScreen(),
        overrides: authOverrides(repository),
      );
      await tester.pumpAndSettle();

      expect(_signUp(tester), isNull);
      await tester.tap(find.text("S'inscrire"));
      // Sans nom, rien ne part.
      await _fill(tester, ['John', ' ', 'a@b.com', 'secret', 'secret']);
      expect(_signUp(tester), isNull);

      await tester.enterText(find.byType(TextField).at(1), 'Doe');
      await tester.pump();
      expect(_signUp(tester), isNotNull);
      expect(repository.calls, isEmpty);
    });

    testWidgets('« Suivant » walks the fields, « OK » signs up', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      await tester.pumpHarness(
        const SignUpScreen(),
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

      const values = ['John', 'Doe', 'a@b.com', 'secret'];
      for (final (index, value) in values.indexed) {
        await tester.enterText(find.byType(TextField).at(index), value);
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        // Le champ suivant, jamais l'œil du mot de passe.
        expect(hasFocus(index + 1), isTrue);
      }
      await tester.enterText(find.byType(TextField).at(4), 'secret');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(repository.calls, ['signUp']);
    });

    testWidgets('lets the password manager fill and create the account', (
      tester,
    ) async {
      await tester.pumpHarness(const SignUpScreen());
      await tester.pumpAndSettle();
      final fields = tester.widgetList<TextField>(find.byType(TextField));

      expect(find.byType(AutofillGroup), findsOneWidget);
      expect(fields.map((field) => field.autofillHints), [
        [AutofillHints.givenName],
        [AutofillHints.familyName],
        [AutofillHints.email],
        [AutofillHints.newPassword],
        [AutofillHints.newPassword],
      ]);
      expect(fields.first.textCapitalization, TextCapitalization.words);
    });

    testWidgets('meets tap target and label guidelines', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpHarness(const SignUpScreen());
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('says what the account brings, in a header', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpHarness(const SignUpScreen());
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Créer un compte')),
        isSemantics(isHeader: true),
      );
      expect(
        find.text('Vos anniversaires vous suivront sur tous vos téléphones.'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('sets its question in French typography', (tester) async {
      await tester.pumpHarness(const SignUpScreen());
      await tester.pumpAndSettle();

      // Espace fine insécable avant « ? », rien après.
      expect(find.text('Vous avez déjà un compte ?'), findsOneWidget);
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

      // Le retour standard, nommé pour TalkBack.
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('shows the whole form at once, with no intro to wait for', (
      tester,
    ) async {
      await tester.pumpHarness(const SignUpScreen());

      // Une seule image : une intro décalée laisserait ses minuteurs en
      // attente, et le test échouerait.
      expect(find.byType(TextField), findsNWidgets(5));
      expect(find.text("S'inscrire"), findsOneWidget);
    });

    testWidgets('keeps its label and disables the form while signing up', (
      tester,
    ) async {
      await tester.pumpHarness(
        const SignUpScreen(),
        overrides: loadingAuthOverrides(),
      );
      // Pas de pumpAndSettle : l'indicateur tourne tant que dure l'attente.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final signUp = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text("S'inscrire"),
          matching: find.byType(FilledButton),
        ),
      );
      expect(signUp.onPressed, isNull);
      final signIn = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Se connecter'),
          matching: find.byType(TextButton),
        ),
      );
      expect(signIn.onPressed, isNull);
    });

    testWidgets('scrolls instead of overflowing on a small phone at 200 %', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpHarness(const SignUpScreen());
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Se connecter'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Se connecter'), findsOneWidget);
    });

    testWidgets('stacks the first and last names at large text', (
      tester,
    ) async {
      Future<bool> namesSideBySide(double textScale) async {
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        await tester.pumpHarness(const SignUpScreen());
        await tester.pumpAndSettle();
        return tester.getTopLeft(find.text('Nom')).dy ==
            tester.getTopLeft(find.text('Prénom')).dy;
      }

      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      expect(await namesSideBySide(1), isTrue);
      // Côte à côte, leurs libellés seraient coupés.
      expect(await namesSideBySide(2), isFalse);
    });
  });
}
