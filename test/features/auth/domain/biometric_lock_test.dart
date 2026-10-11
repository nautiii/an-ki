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
      expect(authAccess(sessionUid: null, lock: locked), AuthAccess.locked);
      expect(
        authAccess(sessionUid: 'u1', lock: locked.copyWith(unlocked: true)),
        AuthAccess.granted,
      );
    });

    test('an account opened by the fingerprint stands in for the session', () {
      const lock = BiometricLock(
        enabled: true,
        unlocked: true,
        unlockedUid: 'bio',
      );

      expect(authAccess(sessionUid: null, lock: lock), AuthAccess.granted);
    });

    test('an unlocked app without any account is signed out', () {
      const lock = BiometricLock(enabled: true, unlocked: true);

      expect(authAccess(sessionUid: null, lock: lock), AuthAccess.signedOut);
    });

    test('a leftover fingerprint account no longer counts once disabled', () {
      const lock = BiometricLock(enabled: false, unlockedUid: 'bio');

      expect(authAccess(sessionUid: null, lock: lock), AuthAccess.signedOut);
    });
  });

  group('BiometricLock', () {
    test('starts locked', () {
      expect(const BiometricLock(enabled: true).unlocked, isFalse);
    });

    test('copyWith keeps or clears the unlocked account', () {
      const lock = BiometricLock(
        enabled: true,
        unlocked: true,
        unlockedUid: 'bio',
      );

      expect(lock.copyWith(unlocked: false).unlockedUid, 'bio');
      expect(lock.copyWith(clearUnlockedUid: true).unlockedUid, isNull);
      expect(lock.copyWith(), lock);
    });

    test('compares by value', () {
      const lock = BiometricLock(enabled: true, unlockedUid: 'bio');

      expect(lock, const BiometricLock(enabled: true, unlockedUid: 'bio'));
      expect(
        lock.hashCode,
        const BiometricLock(enabled: true, unlockedUid: 'bio').hashCode,
      );
      expect(lock, isNot(lock.copyWith(unlocked: true)));
    });
  });
}
