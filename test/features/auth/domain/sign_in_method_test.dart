import 'package:an_ki/features/auth/domain/sign_in_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an anonymous account is a guest, even once it has providers', () {
    expect(
      signInMethodOf(isAnonymous: true, providerIds: const ['google.com']),
      SignInMethod.guest,
    );
  });

  test('an account linked to Google confirms with Google', () {
    expect(
      signInMethodOf(
        isAnonymous: false,
        providerIds: const ['password', 'google.com'],
      ),
      SignInMethod.google,
    );
  });

  test('any other account confirms with its password', () {
    expect(
      signInMethodOf(isAnonymous: false, providerIds: const ['password']),
      SignInMethod.email,
    );
    expect(
      signInMethodOf(isAnonymous: false, providerIds: const []),
      SignInMethod.email,
    );
  });
}
