import 'package:an_ki/features/birthday/domain/birthdays_added.dart';
import 'package:an_ki/features/reminders/domain/reminder_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reminderOfferAfter', () {
    test('an import calls for the offer, whatever the agenda held', () {
      expect(
        reminderOfferAfter(
          const BirthdaysAdded(count: 12, imported: true, first: false),
        ),
        const ReminderOffer(reason: ReminderOfferReason.added, count: 12),
      );
    });

    test('so do the first birthdays added by hand', () {
      expect(
        reminderOfferAfter(
          const BirthdaysAdded(count: 1, imported: false, first: true),
        ),
        const ReminderOffer(reason: ReminderOfferReason.added, count: 1),
      );
    });

    test('one more birthday by hand does not interrupt', () {
      expect(
        reminderOfferAfter(
          const BirthdaysAdded(count: 1, imported: false, first: false),
        ),
        isNull,
      );
    });

    test('nothing added, nothing to offer', () {
      expect(
        reminderOfferAfter(
          const BirthdaysAdded(count: 0, imported: true, first: true),
        ),
        isNull,
      );
    });
  });

  test('offers compare by reason and count', () {
    const offer = ReminderOffer(reason: ReminderOfferReason.restored, count: 3);

    expect(
      offer,
      const ReminderOffer(reason: ReminderOfferReason.restored, count: 3),
    );
    expect(
      offer,
      isNot(const ReminderOffer(reason: ReminderOfferReason.added, count: 3)),
    );
    expect(
      offer.hashCode,
      const ReminderOffer(
        reason: ReminderOfferReason.restored,
        count: 3,
      ).hashCode,
    );
  });
}
