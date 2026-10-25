import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

Birthday _withReminders(Set<ReminderLead>? reminders) => Birthday(
  id: 'lea',
  name: 'Léa',
  surname: '',
  date: const BirthDate(month: 6, day: 30),
  reminders: reminders,
);

void main() {
  test('defaults to a week before and the day, at 10:00', () {
    const preferences = ReminderPreferences();

    expect(preferences.leads, {ReminderLead.weekBefore, ReminderLead.sameDay});
    expect((preferences.hour, preferences.minute), (10, 0));
  });

  group('leadsFor', () {
    const preferences = ReminderPreferences(
      leads: {ReminderLead.dayBefore, ReminderLead.monthBefore},
    );

    test('follows the default setting, earliest first, the day last', () {
      expect(preferences.leadsFor(_withReminders(null)), [
        ReminderLead.monthBefore,
        ReminderLead.dayBefore,
        ReminderLead.sameDay,
      ]);
    });

    test('prefers the own setting of the person, the day always in', () {
      expect(
        preferences.leadsFor(_withReminders(const {ReminderLead.weekBefore})),
        [ReminderLead.weekBefore, ReminderLead.sameDay],
      );
    });

    test('plans nothing for a person without reminders', () {
      expect(preferences.leadsFor(_withReminders(const {})), isEmpty);
    });
  });

  test('compares by value, whatever the order of the leads', () {
    const a = ReminderPreferences(
      leads: {ReminderLead.sameDay, ReminderLead.dayBefore},
      hour: 9,
    );
    const b = ReminderPreferences(
      leads: {ReminderLead.dayBefore, ReminderLead.sameDay},
      hour: 9,
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const ReminderPreferences(hour: 9)));
    expect(
      a,
      isNot(
        const ReminderPreferences(
          leads: {ReminderLead.sameDay, ReminderLead.dayBefore},
          hour: 9,
          minute: 1,
        ),
      ),
    );
  });
}
