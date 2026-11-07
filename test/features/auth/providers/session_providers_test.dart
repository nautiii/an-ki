import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/biometric_lock.dart';
import 'package:an_ki/features/auth/domain/sign_in_method.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:firebase_auth/firebase_auth.dart' show UserInfo;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

/// Compte relié à Google : Firebase le dit par son fournisseur.
class _GoogleUser extends MockUser {
  @override
  List<UserInfo> get providerData => [_GoogleProvider()];
}

class _GoogleProvider extends Fake implements UserInfo {
  @override
  String get providerId => 'google.com';
}

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

  group('isGuestProvider', () {
    test('is true for an anonymous session only', () async {
      final container = makeContainer();
      container.listen(isGuestProvider, (_, _) {});
      await settle();
      expect(container.read(isGuestProvider), isFalse);

      await repository.signInAnonymously();
      await settle();
      expect(container.read(isGuestProvider), isTrue);

      await repository.signInWithGoogle();
      await settle();
      expect(container.read(isGuestProvider), isFalse);
    });
  });

  group('signInMethodProvider', () {
    test('follows the session: none, guest, then e-mail', () async {
      final container = makeContainer();
      container.listen(signInMethodProvider, (_, _) {});
      await settle();
      expect(container.read(signInMethodProvider), isNull);

      await repository.signInAnonymously();
      await settle();
      expect(container.read(signInMethodProvider), SignInMethod.guest);

      // Le compte simulé n'a pas de fournisseur : un compte e-mail.
      await repository.signInWithEmail(email: 'a@b.c', password: 'pwd');
      await settle();
      expect(container.read(signInMethodProvider), SignInMethod.email);
    });

    test('knows a Google account by its provider', () async {
      repository = FakeAuthRepository(user: _GoogleUser());
      final container = makeContainer();
      container.listen(signInMethodProvider, (_, _) {});
      await settle();

      expect(container.read(signInMethodProvider), SignInMethod.google);
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
