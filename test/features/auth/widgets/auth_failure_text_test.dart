import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/widgets/auth_failure_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  testWidgets('every failure has its own message', (tester) async {
    final context = await tester.pumpLocalizedContext();

    expect(
      AuthFailure.wrongPassword.message(context),
      'Mot de passe incorrect.',
    );
    expect(
      AuthFailure.invalidCredentials.message(context),
      'E‑mail ou mot de passe incorrect.',
    );
    expect(
      AuthFailure.network.message(context),
      'Pas de connexion. Vérifiez votre réseau et réessayez.',
    );
    expect(AuthFailure.unknown.message(context), 'Une erreur est survenue.');
    expect(AuthFailure.signInFailed.message(context), 'Erreur de connexion');
    expect(
      AuthFailure.googleSignInFailed.message(context),
      "La connexion avec Google n'a pas abouti. Réessayez.",
    );
    expect(
      AuthFailure.credentialAlreadyInUse.message(context),
      'Ce compte Google a déjà son agenda AnKi. Choisissez-en un autre pour '
      'sauvegarder vos anniversaires.',
    );

    final messages = {
      for (final failure in AuthFailure.values) failure.message(context),
    };
    expect(messages, hasLength(AuthFailure.values.length));
  });
}
