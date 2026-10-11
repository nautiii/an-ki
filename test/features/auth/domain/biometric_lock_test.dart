import 'package:an_ki/features/auth/domain/biometric_lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('authAccess', () {
    test('without biometrics, the Firebase session decides', () {
      expect(
        authAccess(sessionUid: 'u1', lock: BiometricLock.disabled),
        AuthAccess.granted,
      );
      expect(
        authAccess(sessionUid: null, lock: BiometricLock.disabled),
        AuthAccess.signedOut,
      );
    });

    test('with biometrics, a session stays locked until unlocked', () {
      const locked = BiometricLock(enabled: true);

      expect(authAccess(sessionUid: 'u1', lock: locked), AuthAccess.locked);
      expect(
        authAccess(sessionUid: 'u1', lock: locked.copyWith(unlocked: true)),
        AuthAccess.granted,
      );
    });

    test('the lock never opens the app without a session', () {
      const locks = [
        BiometricLock(enabled: true),
        BiometricLock(enabled: true, unlocked: true),
        BiometricLock(enabled: false, unlocked: true),
      ];

      for (final lock in locks) {
        expect(authAccess(sessionUid: null, lock: lock), AuthAccess.signedOut);
      }
    });
  });

  group('BiometricLock', () {
    test('starts locked', () {
      expect(const BiometricLock(enabled: true).unlocked, isFalse);
    });

    test('copyWith changes only what it is given', () {
      const lock = BiometricLock(enabled: true);

      expect(
        lock.copyWith(unlocked: true),
        const BiometricLock(enabled: true, unlocked: true),
      );
      expect(lock.copyWith(enabled: false), BiometricLock.disabled);
      expect(lock.copyWith(), lock);
    });

    test('compares by value', () {
      const lock = BiometricLock(enabled: true, unlocked: true);

      expect(lock, const BiometricLock(enabled: true, unlocked: true));
      expect(
        lock.hashCode,
        const BiometricLock(enabled: true, unlocked: true).hashCode,
      );
      expect(lock, isNot(lock.copyWith(unlocked: false)));
      expect(lock, isNot(lock.copyWith(enabled: false)));
    });
  });
}
