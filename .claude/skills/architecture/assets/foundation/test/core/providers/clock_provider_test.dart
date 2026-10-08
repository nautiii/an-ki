import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clockProvider reads the system clock by default', () {
    final container = ProviderContainer.test();
    final before = DateTime.now();

    final now = container.read(clockProvider)();

    expect(now.isBefore(before), isFalse);
  });

  test('todayProvider truncates the clock to midnight', () {
    final container = ProviderContainer.test(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 3, 12, 15, 30)),
      ],
    );

    expect(container.read(todayProvider), DateTime(2026, 3, 12));
  });

  test('todayProvider rolls over at midnight', () async {
    var now = DateTime(2026, 3, 12, 23, 59, 59, 900);
    final container = ProviderContainer.test(
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    container.listen(todayProvider, (_, _) {});
    expect(container.read(todayProvider), DateTime(2026, 3, 12));

    now = DateTime(2026, 3, 13, 0, 0, 0, 1);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(container.read(todayProvider), DateTime(2026, 3, 13));
  });
}
