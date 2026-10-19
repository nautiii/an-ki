import 'package:an_ki/features/auth/domain/guest_linked.dart';
import 'package:an_ki/features/auth/providers/guest_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const linked = GuestLinked(uid: 'u1', displayName: 'Camille Martin');

  test('knows no link until one, then the last one', () {
    final container = ProviderContainer.test();
    expect(container.read(guestLinksProvider), isNull);

    container.read(guestLinksProvider.notifier).record(linked);

    expect(container.read(guestLinksProvider), linked);
  });

  test('announces every link, even one equal to the last', () {
    final container = ProviderContainer.test();
    final heard = <GuestLinked?>[];
    container.listen(guestLinksProvider, (_, next) => heard.add(next));

    container.read(guestLinksProvider.notifier)
      ..record(linked)
      ..record(linked);

    expect(heard, [linked, linked]);
  });
}
