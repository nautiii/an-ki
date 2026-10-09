import 'package:an_ki/app/shell/navigation_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Session pilotée par le test.
class _Session extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void set(String? uid) => state = uid;
}

final _sessionProvider = NotifierProvider<_Session, String?>(_Session.new);

void main() {
  ProviderContainer makeContainer() {
    final container = ProviderContainer.test(
      overrides: [
        currentUidProvider.overrideWith((ref) => ref.watch(_sessionProvider)),
      ],
    );
    container.listen(navigationProvider, (_, _) {});
    return container;
  }

  test('starts on the birthdays tab and switches tab', () {
    final container = makeContainer();

    expect(container.read(navigationProvider), MainTab.birthdays);
    container.read(navigationProvider.notifier).setTab(MainTab.scanner);
    expect(container.read(navigationProvider), MainTab.scanner);
  });

  test('goes back to the birthdays tab when the session changes', () {
    final container = makeContainer();
    container.read(navigationProvider.notifier).setTab(MainTab.scanner);

    container.read(_sessionProvider.notifier).set(null);

    expect(container.read(navigationProvider), MainTab.birthdays);
  });
}
