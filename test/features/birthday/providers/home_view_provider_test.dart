import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/providers/home_view_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Session pilotable par le test.
final _session = NotifierProvider<_Session, String?>(_Session.new);

class _Session extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void signIn(String? uid) => state = uid;
}

void main() {
  ProviderContainer makeContainer() => ProviderContainer.test(
    overrides: [currentUidProvider.overrideWith((ref) => ref.watch(_session))],
  );

  test('starts on the agenda and shows the chosen view', () {
    final container = makeContainer();

    expect(container.read(homeViewProvider), HomeView.agenda);
    container.read(homeViewProvider.notifier).show(HomeView.calendar);
    expect(container.read(homeViewProvider), HomeView.calendar);
  });

  test('goes back to the agenda when the user changes', () {
    final container = makeContainer();
    container.listen(homeViewProvider, (_, _) {});
    container.read(homeViewProvider.notifier).show(HomeView.calendar);

    container.read(_session.notifier).signIn('u2');

    expect(container.read(homeViewProvider), HomeView.agenda);
  });
}
