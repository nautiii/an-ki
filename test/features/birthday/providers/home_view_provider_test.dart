import 'package:an_ki/features/birthday/providers/home_view_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toggles between list and calendar', () {
    final container = ProviderContainer.test();

    expect(container.read(homeViewProvider), HomeViewType.list);
    container.read(homeViewProvider.notifier).toggle();
    expect(container.read(homeViewProvider), HomeViewType.calendar);
    container.read(homeViewProvider.notifier).toggle();
    expect(container.read(homeViewProvider), HomeViewType.list);
  });
}
