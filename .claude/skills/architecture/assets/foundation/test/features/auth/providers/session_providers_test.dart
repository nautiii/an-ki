import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

void main() {
  ProviderContainer makeContainer(AuthState initial) => ProviderContainer.test(
    overrides: [
      authProvider.overrideWith(() => FakeAuthNotifier(initialState: initial)),
    ],
  );

  test('exposes the signed-in user id', () {
    final container = makeContainer(AuthState(user: MockUser()));

    expect(container.read(currentUidProvider), 'fake-uid');
  });

  test('falls back to the biometric session id', () {
    final container = makeContainer(AuthState(biometricUid: 'bio-uid'));

    expect(container.read(currentUidProvider), 'bio-uid');
  });

  test('follows sign-in and sign-out', () {
    final container = makeContainer(AuthState());
    container.listen(currentUidProvider, (_, _) {});
    final auth = container.read(authProvider.notifier);

    // Les dépendants sont notifiés en différé : on relit après chaque changement.
    auth.state = AuthState(user: MockUser());
    expect(container.read(currentUidProvider), 'fake-uid');

    auth.state = AuthState();
    expect(container.read(currentUidProvider), isNull);
  });
}
