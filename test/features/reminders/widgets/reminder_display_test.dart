import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/reminders/domain/reminder_plan.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:an_ki/features/reminders/widgets/reminder_display.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  final hugo = PlannedReminder(
    id: 1,
    lead: ReminderLead.sameDay,
    birthdayId: 'hugo',
    name: 'Hugo',
    surname: 'Bernard',
    age: 34,
    at: DateTime(2026, 10, 21, 10),
  );

  testWidgets('words the reminder time and day in French', (tester) async {
    final context = await tester.pumpLocalizedContext();

    expect(context.reminderTime(const ReminderPreferences()), '10:00');
    expect(
      context.reminderTime(const ReminderPreferences(hour: 8, minute: 5)),
      '08:05',
    );
    expect(context.reminderDay(hugo), 'mercredi 21 octobre');
    expect(context.reminderClock(hugo), '10:00');
  });

  testWidgets('sums up a preference, the day itself always last', (
    tester,
  ) async {
    final context = await tester.pumpLocalizedContext();

    expect(
      context.reminderSchedule(const ReminderPreferences()),
      '7 jours avant · Le jour J · 10:00',
    );
    expect(
      context.reminderSchedule(
        const ReminderPreferences(
          leads: {ReminderLead.dayBefore, ReminderLead.monthBefore},
          hour: 9,
        ),
      ),
      '30 jours avant · La veille · Le jour J · 09:00',
    );
  });
}
