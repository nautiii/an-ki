import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/widgets/auth_failure_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  testWidgets('every failure has its own message', (tester) async {
    final context = await tester.pumpLocalizedContext();

    expect(
      AuthFailure.wrongPassword.message(context),
      'Mot de passe incorrect. Réessayez, ou demandez un nouveau mot de '
      'passe.',
    );
    expect(
      AuthFailure.invalidCredentials.message(context),
      'E\u2011mail ou mot de passe incorrect. Vérifiez-les, ou demandez un '
      'nouveau mot de passe.',
    );
    expect(
      AuthFailure.network.message(context),
      'Pas de connexion. Vérifiez votre réseau et réessayez.',
    );
    expect(
      AuthFailure.unknown.message(context),
      "Quelque chose s'est mal passé. Réessayez dans un instant.",
    );
    expect(
      AuthFailure.signInFailed.message(context),
      "La connexion n'a pas abouti. Réessayez dans un instant.",
    );
    expect(
      AuthFailure.userNotFound.message(context),
      'Aucun compte AnKi avec cette adresse. Vérifiez-la, ou créez un compte.',
    );
    expect(
      AuthFailure.tooManyRequests.message(context),
      "Trop d'essais d'affilée. Patientez quelques minutes, puis réessayez.",
    );
    expect(
      AuthFailure.passwordResetFailed.message(context),
      "Le lien n'a pas pu partir. Réessayez dans un instant.",
    );
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
