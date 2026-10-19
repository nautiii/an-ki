import 'package:an_ki/features/auth/domain/guest_linked.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('links compare by account and name', () {
    const linked = GuestLinked(uid: 'u1', displayName: 'Camille Martin');

    expect(linked, const GuestLinked(uid: 'u1', displayName: 'Camille Martin'));
    expect(
      linked,
      isNot(const GuestLinked(uid: 'u2', displayName: 'Camille Martin')),
    );
    expect(linked, isNot(const GuestLinked(uid: 'u1', displayName: 'Camille')));
    expect(
      linked.hashCode,
      const GuestLinked(uid: 'u1', displayName: 'Camille Martin').hashCode,
    );
  });
}
