import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/reminders/providers/next_birthday_reminder_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hugo = Birthday(
    id: 'hugo',
    name: 'Hugo',
    surname: 'Bernard',
    date: BirthDate(year: 1992, month: 10, day: 21),
  );
  const louis = Birthday(
    id: 'louis',
    name: 'Louis',
    surname: 'Petit',
    date: BirthDate(month: 12, day: 2),
  );

  ProviderContainer makeContainer(List<Birthday> birthdays) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        birthdaysProvider.overrideWithValue(AsyncData(birthdays)),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 19, 9)),
      ],
    );
    container.listen(nextBirthdayReminderProvider, (_, _) {});
    return container;
  }

  test('is the next reminder of the day itself', () {
    final reminder = makeContainer(const [louis, hugo])
        .read(nextBirthdayReminderProvider)!;

    expect(reminder.fullName, 'Hugo Bernard');
    expect(reminder.at, DateTime(2026, 10, 21, 10));
  });

  test('is null with an empty agenda', () {
    expect(makeContainer(const []).read(nextBirthdayReminderProvider), isNull);
  });
}
