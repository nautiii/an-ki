import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/birthday/domain/birthday_model.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/reminders/providers/reminder_sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Service de notifications qui enregistre chaque replanification.
class _RecordingNotificationService extends Fake
    implements NotificationService {
  final scheduled = <List<ReminderNotification>>[];

  @override
  Future<void> scheduleAll(List<ReminderNotification> reminders) async =>
      scheduled.add(reminders);
}

void main() {
  final lea = BirthdayModel(
    id: 'lea',
    name: 'Léa',
    surname: 'Martin',
    date: DateTime(1994, 3, 12),
  );

  late _RecordingNotificationService notifications;
  late StreamController<List<BirthdayModel>> birthdays;

  setUp(() {
    notifications = _RecordingNotificationService();
    birthdays = StreamController<List<BirthdayModel>>();
    addTearDown(birthdays.close);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        birthdaysProvider.overrideWith((ref) => birthdays.stream),
        clockProvider.overrideWithValue(() => DateTime(2026, 3, 1, 9)),
      ],
    );
    container.listen(reminderSyncProvider, (_, _) {});
    return container;
  }

  test('schedules the planned reminders of every new list', () async {
    makeContainer();

    birthdays.add([lea]);
    await Future<void>.delayed(Duration.zero);
    // Déconnexion : la liste vide annule les rappels.
    birthdays.add(const []);
    await Future<void>.delayed(Duration.zero);

    final base = 'lea'.hashCode.abs() % 100000;
    expect(notifications.scheduled, [
      [
        ReminderNotification(
          id: base,
          type: ReminderType.birthday,
          name: 'Léa',
          surname: 'Martin',
          age: 32,
          at: DateTime(2026, 3, 12, 10),
        ),
        ReminderNotification(
          id: base + 500000,
          type: ReminderType.weekBefore,
          name: 'Léa',
          surname: 'Martin',
          age: 32,
          at: DateTime(2026, 3, 5, 10),
        ),
      ],
      isEmpty,
    ]);
  });

  test('ignores loading and error states', () async {
    makeContainer();

    birthdays.addError(Exception('offline'));
    await Future<void>.delayed(Duration.zero);

    expect(notifications.scheduled, isEmpty);
  });
}
