import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/auth_overrides.dart';
import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  group('WelcomeScreen', () {
    testWidgets('makes one promise and offers two actions', (tester) async {
      await tester.pumpHarness(const WelcomeScreen());
      await tester.pumpAndSettle();

      expect(find.text('Ne ratez plus aucun anniversaire'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Ne ratez plus aucun anniversaire'),
        findsOneWidget,
      );
      expect(find.text('Commencer'), findsOneWidget);
      expect(find.text("J'ai déjà un compte"), findsOneWidget);
    });

    testWidgets('« Commencer » opens AnKi as a guest', (tester) async {
      final repository = FakeAuthRepository();
      await tester.pumpHarness(
        const WelcomeScreen(),
        overrides: authOverrides(repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['signInAnonymously']);
      expect(repository.currentUser?.isAnonymous, isTrue);
    });

    testWidgets('says what to do when starting offline', (tester) async {
      await tester.pumpHarness(
        const WelcomeScreen(),
        overrides: authOverrides(
          FakeAuthRepository(failure: AuthFailure.network),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
        findsOneWidget,
      );
      // Rien n'est bloqué : on peut réessayer.
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Commencer'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('keeps its label and disables both actions while starting', (
      tester,
    ) async {
      await tester.pumpHarness(
        const WelcomeScreen(),
        overrides: loadingAuthOverrides(),
      );
      // Pas de pumpAndSettle : l'indicateur tourne tant que dure l'attente.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final start = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Commencer'),
          matching: find.byType(FilledButton),
        ),
      );
      final signIn = tester.widget<TextButton>(
        find.ancestor(
          of: find.text("J'ai déjà un compte"),
          matching: find.byType(TextButton),
        ),
      );
      expect(start.onPressed, isNull);
      expect(signIn.onPressed, isNull);
    });

    testWidgets('« J\'ai déjà un compte » opens the sign-in', (tester) async {
      await tester.pumpHarness(
        const WelcomeScreen(),
        routes: {
          AppRoutes.auth: (_) => const Scaffold(body: Text('Sign-in Route')),
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("J'ai déjà un compte"));
      await tester.pumpAndSettle();

      expect(find.text('Sign-in Route'), findsOneWidget);
    });

    testWidgets('scrolls instead of overflowing on a small phone at 200 %', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpHarness(const WelcomeScreen());
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text("J'ai déjà un compte"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text("J'ai déjà un compte"), findsOneWidget);
    });

    testWidgets('meets tap target and label guidelines', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpHarness(const WelcomeScreen());
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });
}
