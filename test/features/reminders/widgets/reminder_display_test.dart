import 'package:an_ki/features/reminders/domain/reminder_plan.dart';
import 'package:an_ki/features/reminders/widgets/reminder_display.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  final hugo = PlannedReminder(
    id: 1,
    kind: ReminderKind.birthday,
    birthdayId: 'hugo',
    name: 'Hugo',
    surname: 'Bernard',
    age: 34,
    at: DateTime(2026, 10, 21, 10),
  );

  testWidgets('words the reminder time and day in French', (tester) async {
    final context = await tester.pumpLocalizedContext();

    expect(context.reminderTime, '10:00');
    expect(context.reminderDay(hugo), 'mercredi 21 octobre');
    expect(context.reminderClock(hugo), '10:00');
  });
}
