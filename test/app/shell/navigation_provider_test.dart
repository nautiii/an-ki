import 'package:an_ki/app/shell/navigation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts on the birthdays tab and switches tab', () {
    final container = ProviderContainer.test();

    expect(container.read(navigationProvider), MainTab.birthdays);
    container.read(navigationProvider.notifier).setTab(MainTab.scanner);
    expect(container.read(navigationProvider), MainTab.scanner);
  });
}
