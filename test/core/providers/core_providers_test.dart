import 'package:an_ki/core/providers/navigation_provider.dart';
import 'package:an_ki/features/birthday/providers/home_view_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavigationNotifier', () {
    test('defaults to the birthdays tab and switches tab', () {
      final container = ProviderContainer.test();

      expect(container.read(navigationProvider), MainTab.birthdays);
      container.read(navigationProvider.notifier).setTab(MainTab.scanner);
      expect(container.read(navigationProvider), MainTab.scanner);
    });
  });

  group('HomeViewNotifier', () {
    test('toggles between list and calendar', () {
      final container = ProviderContainer.test();

      expect(container.read(homeViewProvider), HomeViewType.list);
      container.read(homeViewProvider.notifier).toggle();
      expect(container.read(homeViewProvider), HomeViewType.calendar);
      container.read(homeViewProvider.notifier).toggle();
      expect(container.read(homeViewProvider), HomeViewType.list);
    });
  });
}
