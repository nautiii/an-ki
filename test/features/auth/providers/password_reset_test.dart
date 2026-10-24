import 'dart:async';

import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/providers/password_reset.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

/// Dépôt dont l'envoi du lien attend que le test le termine.
class _SlowAuthRepository extends FakeAuthRepository {
  final sending = Completer<void>();

  @override
  Future<void> sendPasswordReset(
    String email, {
    required String languageCode,
  }) async {
    calls.add('sendPasswordReset');
    await sending.future;
  }
}

void main() {
  ProviderContainer makeContainer(FakeAuthRepository repository) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    // Provider autoDispose : un listener le garde en vie pendant le test.
    container.listen(passwordResetProvider, (_, _) {});
    return container;
  }

  test('starts with no link sent', () {
    final container = makeContainer(FakeAuthRepository());

    expect(
      container.read(passwordResetProvider),
      const AsyncData<String?>(null),
    );
  });

  test('sends the link to the trimmed address and keeps it', () async {
    final repository = FakeAuthRepository();
    final container = makeContainer(repository);

    final sent = await container
        .read(passwordResetProvider.notifier)
        .send('  lea@exemple.fr ', languageCode: 'en');

    expect(sent, isTrue);
    expect(repository.passwordResets, [('lea@exemple.fr', 'en')]);
    expect(container.read(passwordResetProvider).value, 'lea@exemple.fr');
  });

  test('publishes a refusal as its failure', () async {
    final container = makeContainer(
      FakeAuthRepository(resetFailure: AuthFailure.invalidEmail),
    );

    final sent = await container
        .read(passwordResetProvider.notifier)
        .send('lea', languageCode: 'fr');

    expect(sent, isFalse);
    expect(
      container.read(passwordResetProvider).error,
      AuthFailure.invalidEmail,
    );
  });

  test('an unexpected error becomes passwordResetFailed', () async {
    final container = makeContainer(
      FakeAuthRepository(resetFailure: Exception('plugin')),
    );

    await container
        .read(passwordResetProvider.notifier)
        .send('lea@exemple.fr', languageCode: 'fr');

    expect(
      container.read(passwordResetProvider).error,
      AuthFailure.passwordResetFailed,
    );
  });

  test('ignores a second tap while the first link leaves', () async {
    final repository = _SlowAuthRepository();
    final container = makeContainer(repository);
    final reset = container.read(passwordResetProvider.notifier);

    final first = reset.send('lea@exemple.fr', languageCode: 'fr');
    expect(container.read(passwordResetProvider).isLoading, isTrue);
    expect(await reset.send('lea@exemple.fr', languageCode: 'fr'), isFalse);

    repository.sending.complete();
    expect(await first, isTrue);
    expect(repository.calls, ['sendPasswordReset']);
  });
}
