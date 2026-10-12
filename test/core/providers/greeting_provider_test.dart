import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/providers/greeting_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int hour, int minute, [int second = 0]) =>
    DateTime(2026, 10, 12, hour, minute, second);

void main() {
  group('greetingAt', () {
    test('says hello from 6:01 to 18:00 included', () {
      expect(greetingAt(_at(6, 1)), Greeting.day);
      expect(greetingAt(_at(12, 0)), Greeting.day);
      expect(greetingAt(_at(18, 0, 59)), Greeting.day);
    });

    test('says good evening from 18:01 to 6:00 included', () {
      expect(greetingAt(_at(18, 1)), Greeting.evening);
      expect(greetingAt(_at(23, 59)), Greeting.evening);
      expect(greetingAt(_at(0, 0)), Greeting.evening);
      expect(greetingAt(_at(6, 0, 59)), Greeting.evening);
    });
  });

  group('nextGreetingChange', () {
    test('is 6:01 the same morning before dawn', () {
      expect(nextGreetingChange(_at(5, 30)), _at(6, 1));
    });

    test('is 18:01 the same day during the day', () {
      expect(nextGreetingChange(_at(6, 1)), _at(18, 1));
      expect(nextGreetingChange(_at(18, 0, 30)), _at(18, 1));
    });

    test('is 6:01 the next morning in the evening', () {
      expect(nextGreetingChange(_at(18, 1)), DateTime(2026, 10, 13, 6, 1));
    });
  });

  test('greetingProvider follows the clock', () {
    final container = ProviderContainer.test(
      overrides: [clockProvider.overrideWithValue(() => _at(20, 0))],
    );

    expect(container.read(greetingProvider), Greeting.evening);
  });

  test('greetingProvider switches at 18:01', () async {
    var now = _at(18, 0, 59).add(const Duration(milliseconds: 900));
    final container = ProviderContainer.test(
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    container.listen(greetingProvider, (_, _) {});
    expect(container.read(greetingProvider), Greeting.day);

    now = _at(18, 1);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(container.read(greetingProvider), Greeting.evening);
  });
}
