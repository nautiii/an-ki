import 'dart:math' as math;

import 'package:an_ki/core/theme/themes.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/widgets/auth_error_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

/// Rapport de contraste WCAG entre deux couleurs opaques.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (label, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('error text reads on the error background ($label)', (
      tester,
    ) async {
      await tester.pumpHarness(
        Theme(
          data: theme,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showAuthErrorSnackBar(context, AuthFailure.network),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      const message = 'Pas de connexion. Vérifiez votre réseau et réessayez.';
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      final text = tester.widget<Text>(find.text(message));
      final scheme = theme.colorScheme;

      expect(snackBar.backgroundColor, scheme.error);
      expect(text.style?.color, scheme.onError);
      expect(
        _contrast(scheme.onError, scheme.error),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  testWidgets('an unexpected error gets the generic message', (tester) async {
    await tester.pumpHarness(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAuthErrorSnackBar(context, StateError('x')),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(
      find.text("Quelque chose s'est mal passé. Réessayez dans un instant."),
      findsOneWidget,
    );
  });
}
