import 'package:an_ki/features/auth/providers/fresh_sign_in_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('knows no account until a sign-in, then the last one', () {
    final container = ProviderContainer.test();
    expect(container.read(freshSignInProvider), isNull);

    container.read(freshSignInProvider.notifier)
      ..record('u1')
      ..record('u2');

    expect(container.read(freshSignInProvider), 'u2');
  });
}
