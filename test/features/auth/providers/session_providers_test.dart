import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/biometric_lock.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

void main() {
  late FakeAuthRepository repository;
  late FakeBiometricService biometrics;

  setUp(() {
    repository = FakeAuthRepository();
    biometrics = FakeBiometricService();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        biometricServiceProvider.overrideWithValue(biometrics),
      ],
    );
    // Riverpod met en pause un provider sans écouteur.
    container.listen(currentUidProvider, (_, _) {});
    container.listen(authAccessProvider, (_, _) {});
    return container;
  }

  /// Laisse arriver la session et le verrou.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('currentUidProvider', () {
    test('exposes the signed-in user id', () async {
      repository = FakeAuthRepository(user: MockUser());
      final container = makeContainer();
      await settle();

      expect(container.read(currentUidProvider), 'fake-uid');
    });

    test('follows sign-in and sign-out', () async {
      final container = makeContainer();
      await settle();
      expect(container.read(currentUidProvider), isNull);

      await repository.signInWithEmail(email: 'a', password: 'b');
      await settle();
      expect(container.read(currentUidProvider), 'fake-uid');

      await repository.signOutFirebase();
      await settle();
      expect(container.read(currentUidProvider), isNull);
    });
  });

  group('biometricLockProvider', () {
    Future<BiometricLock> lockFor(FakeBiometricService service) {
      biometrics = service;
      return makeContainer().read(biometricLockProvider.future);
    }

    test('is enabled and locked with a fingerprint and a token', () async {
      expect(
        await lockFor(FakeBiometricService(available: true, token: 'tok')),
        const BiometricLock(enabled: true),
      );
    });

    test('is disabled without a token or without a sensor', () async {
      expect(
        await lockFor(FakeBiometricService(available: true)),
        BiometricLock.disabled,
      );
      expect(
        await lockFor(FakeBiometricService(token: 'tok')),
        BiometricLock.disabled,
      );
    });
  });

  group('authAccessProvider', () {
    test('is unknown until the session and the lock are read', () {
      final container = makeContainer();

      expect(container.read(authAccessProvider), isNull);
    });

    test('grants a session without biometrics', () async {
      repository = FakeAuthRepository(user: MockUser());
      final container = makeContainer();
      await settle();

      expect(container.read(authAccessProvider), AuthAccess.granted);
    });

    test('is signed out without a session', () async {
      final container = makeContainer();
      await settle();

      expect(container.read(authAccessProvider), AuthAccess.signedOut);
    });

    test('a fingerprint without a session opens nothing', () async {
      biometrics = FakeBiometricService(
        available: true,
        token: 'tok',
        userId: 'bio-uid',
      );
      final container = makeContainer();
      await settle();

      container.read(biometricLockProvider.notifier).unlock();

      expect(container.read(authAccessProvider), AuthAccess.signedOut);
      expect(container.read(currentUidProvider), isNull);
    });

    test('locks a restored session until it is unlocked', () async {
      repository = FakeAuthRepository(user: MockUser());
      biometrics = FakeBiometricService(available: true, token: 'tok');
      final container = makeContainer();
      await settle();

      expect(container.read(authAccessProvider), AuthAccess.locked);
      // Verrouillée, l'app garde la session : données et rappels suivent.
      expect(container.read(currentUidProvider), 'fake-uid');

      container.read(biometricLockProvider.notifier).unlock();
      expect(container.read(authAccessProvider), AuthAccess.granted);

      container.read(biometricLockProvider.notifier).lock();
      expect(container.read(authAccessProvider), AuthAccess.locked);
      expect(container.read(currentUidProvider), 'fake-uid');
    });
  });
}
