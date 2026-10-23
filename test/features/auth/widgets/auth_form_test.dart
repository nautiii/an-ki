import 'package:an_ki/features/auth/widgets/auth_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  group('AuthFormHeader', () {
    testWidgets('marks its title as a header above the message', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpHarness(
        const AuthFormHeader(title: 'Connexion', message: 'Bienvenue'),
      );

      expect(
        tester.getSemantics(find.text('Connexion')),
        isSemantics(isHeader: true),
      );
      expect(find.text('Bienvenue'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('AuthSubmitButton', () {
    FilledButton button(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    testWidgets('sends the form when tapped', (tester) async {
      var sent = 0;
      await tester.pumpHarness(
        AuthSubmitButton(
          label: 'Se connecter',
          loading: false,
          onPressed: () => sent++,
        ),
      );

      await tester.tap(find.text('Se connecter'));

      expect(sent, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('is disabled without an action', (tester) async {
      await tester.pumpHarness(
        const AuthSubmitButton(label: 'Se connecter', loading: false),
      );

      expect(button(tester).onPressed, isNull);
    });

    testWidgets('keeps its label and waits while loading', (tester) async {
      await tester.pumpHarness(
        AuthSubmitButton(
          label: 'Se connecter',
          loading: true,
          onPressed: () {},
        ),
      );

      expect(button(tester).onPressed, isNull);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AuthSwitchPrompt', () {
    testWidgets('runs its action', (tester) async {
      var opened = 0;
      await tester.pumpHarness(
        AuthSwitchPrompt(
          question: 'Pas encore de compte ?',
          action: "S'inscrire",
          onPressed: () => opened++,
        ),
      );

      expect(find.text('Pas encore de compte ?'), findsOneWidget);
      await tester.tap(find.text("S'inscrire"));

      expect(opened, 1);
    });

    testWidgets('wraps instead of overflowing at 200 %', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpHarness(
        const Center(
          child: SizedBox(
            width: 312,
            child: AuthSwitchPrompt(
              question: 'Vous avez déjà un compte ?',
              action: 'Se connecter',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('Se connecter')).dy,
        greaterThan(
          tester.getTopLeft(find.text('Vous avez déjà un compte ?')).dy,
        ),
      );
    });
  });
}
