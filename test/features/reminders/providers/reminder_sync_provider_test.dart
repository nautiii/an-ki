import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
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
  final lea = Birthday(
    id: 'lea',
    name: 'Léa',
    surname: 'Martin',
    date: BirthDate.fromDate(DateTime(1994, 3, 12)),
  );

  late _RecordingNotificationService notifications;
  late StreamController<List<Birthday>> birthdays;

  setUp(() {
    notifications = _RecordingNotificationService();
    birthdays = StreamController<List<Birthday>>();
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

  test('schedules both reminders of birthdays whose ids collide', () async {
    // Deux ids visant le même emplacement (formule historique) : avant, le
    // second écrasait le jour J et le J-7 du premier.
    int slot(String id) => id.hashCode.abs() % 100000;
    final seen = <int, String>{};
    late final String first;
    late final String second;
    for (var i = 0; ; i++) {
      final id = 'birthday-$i';
      if (seen[slot(id)] case final other?) {
        (first, second) = (other, id);
        break;
      }
      seen[slot(id)] = id;
    }
    makeContainer();

    birthdays.add([
      Birthday(id: first, name: 'Léa', surname: 'Martin', date: lea.date),
      Birthday(id: second, name: 'Hugo', surname: 'Martin', date: lea.date),
    ]);
    await Future<void>.delayed(Duration.zero);

    final reminders = notifications.scheduled.single;
    expect(reminders.map((r) => r.id).toSet(), hasLength(4));
    for (final name in ['Léa', 'Hugo']) {
      expect(
        reminders.where((r) => r.name == name).map((r) => r.type),
        unorderedEquals(ReminderType.values),
      );
    }
  });
}
