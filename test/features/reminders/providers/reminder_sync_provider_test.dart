import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/reminders/data/reminder_preferences_repository.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:an_ki/features/reminders/providers/reminder_preferences_provider.dart';
import 'package:an_ki/features/reminders/providers/reminder_sync_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

/// Service de notifications qui enregistre chaque replanification.
class _RecordingNotificationService extends Fake
    implements NotificationService {
  final scheduled = <List<ReminderNotification>>[];

  @override
  Future<void> scheduleAll(List<ReminderNotification> reminders) async =>
      scheduled.add(reminders);
}

/// Laisse passer les flux (anniversaires, réglage) et les reconstructions que
/// Riverpod planifie après eux.
Future<void> settle() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
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
  late RecordingReminderPreferencesRepository preferences;

  setUp(() {
    notifications = _RecordingNotificationService();
    birthdays = StreamController<List<Birthday>>.broadcast();
    addTearDown(birthdays.close);
    preferences = RecordingReminderPreferencesRepository();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        authUserProvider.overrideWithValue(AsyncData(MockUser(uid: 'u1'))),
        birthdaysProvider.overrideWith((ref) => birthdays.stream),
        reminderPreferencesRepositoryProvider.overrideWithValue(preferences),
        clockProvider.overrideWithValue(() => DateTime(2026, 3, 1, 9)),
      ],
    );
    container.listen(reminderSyncProvider, (_, _) {});
    return container;
  }

  test('schedules the planned reminders of every new list', () async {
    makeContainer();
    await settle();

    birthdays.add([lea]);
    await settle();
    // Déconnexion : la liste vide annule les rappels.
    birthdays.add(const []);
    await settle();

    final base = 'lea'.hashCode.abs() % 100000;
    expect(notifications.scheduled, [
      [
        // L'id de l'anniversaire voyage avec la notification.
        ReminderNotification(
          id: base + 500000,
          daysBefore: 7,
          name: 'Léa',
          surname: 'Martin',
          age: 32,
          at: DateTime(2026, 3, 5, 10),
          payload: 'lea',
        ),
        ReminderNotification(
          id: base,
          daysBefore: 0,
          name: 'Léa',
          surname: 'Martin',
          age: 32,
          at: DateTime(2026, 3, 12, 10),
          payload: 'lea',
        ),
      ],
      isEmpty,
    ]);
  });

  test('replans with the preferences, as soon as they change', () async {
    final container = makeContainer();
    await settle();
    birthdays.add([lea]);
    await settle();
    container.listen(reminderPreferencesEditorProvider, (_, _) {});

    await container
        .read(reminderPreferencesEditorProvider.notifier)
        .setTime(hour: 8, minute: 30);
    await settle();

    expect(notifications.scheduled.last.map((r) => r.at), [
      DateTime(2026, 3, 5, 8, 30),
      DateTime(2026, 3, 12, 8, 30),
    ]);
  });

  test('keeps reminding with the former cadence if preferences fail', () async {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        authUserProvider.overrideWithValue(AsyncData(MockUser(uid: 'u1'))),
        birthdaysProvider.overrideWith((ref) => birthdays.stream),
        reminderPreferencesProvider.overrideWithValue(
          AsyncError<ReminderPreferences>(
            Exception('denied'),
            StackTrace.empty,
          ),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 3, 1, 9)),
      ],
    );
    container.listen(reminderSyncProvider, (_, _) {});

    birthdays.add([lea]);
    await settle();

    expect(notifications.scheduled.single.map((r) => r.daysBefore), [7, 0]);
  });

  test('ignores loading and error states', () async {
    makeContainer();
    await settle();

    birthdays.addError(Exception('offline'));
    await settle();

    expect(notifications.scheduled, isEmpty);
  });

  group('with the real session', () {
    late StreamController<User?> auth;

    setUp(() {
      auth = StreamController<User?>.broadcast();
      addTearDown(auth.close);
    });

    // Session restaurée par Firebase au rythme du test ; anniversaires dérivés
    // de l'uid comme dans l'app.
    void makeSessionContainer() {
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          notificationServiceProvider.overrideWithValue(notifications),
          authUserProvider.overrideWith((ref) => auth.stream),
          birthdayRepositoryProvider.overrideWithValue(
            RecordingBirthdayRepository(initial: [lea]),
          ),
          reminderPreferencesRepositoryProvider.overrideWithValue(preferences),
          clockProvider.overrideWithValue(() => DateTime(2026, 3, 1, 9)),
        ],
      );
      container.listen(reminderSyncProvider, (_, _) {});
    }

    test('cancels nothing while the session is restored', () async {
      makeSessionContainer();
      await settle();
      expect(notifications.scheduled, isEmpty);

      auth.add(MockUser(uid: 'u1'));
      await settle();

      expect(notifications.scheduled.single, hasLength(2));
    });

    test('cancels every reminder on sign-out', () async {
      makeSessionContainer();
      auth.add(MockUser(uid: 'u1'));
      await settle();

      auth.add(null);
      await settle();

      expect(notifications.scheduled, [hasLength(2), isEmpty]);
    });

    test('cancels every reminder when no session is restored', () async {
      makeSessionContainer();
      auth.add(null);
      await settle();

      expect(notifications.scheduled, [isEmpty]);
    });
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
    await settle();

    birthdays.add([
      Birthday(id: first, name: 'Léa', surname: 'Martin', date: lea.date),
      Birthday(id: second, name: 'Hugo', surname: 'Martin', date: lea.date),
    ]);
    await settle();

    final reminders = notifications.scheduled.single;
    expect(reminders.map((r) => r.id).toSet(), hasLength(4));
    for (final name in ['Léa', 'Hugo']) {
      expect(
        reminders.where((r) => r.name == name).map((r) => r.daysBefore),
        unorderedEquals([7, 0]),
      );
    }
  });
}
