import 'dart:async';

import 'package:an_ki/app/bootstrap/background_replan.dart';
import 'package:an_ki/app/bootstrap/notification_strings.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/reminders/data/reminder_preferences_repository.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';

import '../../support/fake_providers.dart';

/// Service de notifications qui garde les textes reçus et chaque plan ;
/// [whileScheduling] joue ce qui se passe pendant la première planification.
class _RecordingNotificationService extends Fake
    implements NotificationService {
  NotificationStrings? strings;
  final scheduled = <List<ReminderNotification>>[];
  Future<void> Function()? whileScheduling;

  @override
  Future<void> scheduleAll(
    List<ReminderNotification> reminders, {
    required NotificationStrings strings,
  }) async {
    this.strings = strings;
    scheduled.add(reminders);
    final during = whileScheduling;
    whileScheduling = null;
    await during?.call();
  }
}

/// Anniversaires vus comme le cache de Firestore : la liste courante à
/// l'abonnement, puis chaque [emit] ; [failure] fait échouer la lecture.
class _LiveBirthdayRepository extends FakeBirthdayRepository {
  _LiveBirthdayRepository(this._current, {this.failure});

  List<Birthday> _current;
  final Exception? failure;
  final watchedUids = <String>[];
  final _changes = StreamController<List<Birthday>>.broadcast();

  void emit(List<Birthday> birthdays) => _changes.add(_current = birthdays);

  @override
  Stream<List<Birthday>> watchBirthdays(String uid) {
    watchedUids.add(uid);
    if (failure case final failure?) return Stream.error(failure);
    final controller = StreamController<List<Birthday>>();
    final changes = _changes.stream.listen(controller.add);
    controller
      ..onCancel = () async {
        await changes.cancel();
        await controller.close();
      }
      ..add(_current);
    return controller.stream;
  }
}

/// Profil illisible, comme une règle Firestore qui refuse la lecture.
class _FailingUserRepository extends FakeUserRepository {
  @override
  Stream<UserProfile?> watchUser(String uid) =>
      Stream.error(Exception('denied'));
}

/// Réglage illisible, comme une règle Firestore qui refuse la lecture.
class _FailingPreferencesRepository extends Fake
    implements ReminderPreferencesRepository {
  @override
  Stream<ReminderPreferences> watchPreferences(String uid) =>
      Stream.error(Exception('denied'));
}

/// WorkManager qui enregistre les appels, ou échoue si [failure] est défini.
class _RecordingWorkmanager extends Fake implements Workmanager {
  _RecordingWorkmanager({this.failure});

  final Exception? failure;
  Function? dispatcher;
  final periodic =
      <
        (String, String, Duration?, ExistingPeriodicWorkPolicy?, Constraints?)
      >[];

  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) async {
    if (failure case final failure?) throw failure;
    dispatcher = callbackDispatcher;
  }

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async => periodic.add((
    uniqueName,
    taskName,
    frequency,
    existingWorkPolicy,
    constraints,
  ));
}

void main() {
  group('registerBackgroundReplan', () {
    test('keeps one daily replan task on Android, offline too', () async {
      final workmanager = _RecordingWorkmanager();

      await registerBackgroundReplan(workmanager);

      expect(workmanager.dispatcher, same(backgroundReplanDispatcher));
      expect(workmanager.periodic, [
        (
          backgroundReplanTask,
          backgroundReplanTask,
          const Duration(hours: 24),
          ExistingPeriodicWorkPolicy.keep,
          // Aucune contrainte : la replanification tourne aussi hors ligne.
          null,
        ),
      ]);
    });

    test('registers nothing on iOS yet', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final workmanager = _RecordingWorkmanager();

      await registerBackgroundReplan(workmanager);

      expect(workmanager.dispatcher, isNull);
      expect(workmanager.periodic, isEmpty);
    });

    test('lets the app start when registration fails', () async {
      final workmanager = _RecordingWorkmanager(
        failure: Exception('no WorkManager'),
      );

      await expectLater(registerBackgroundReplan(workmanager), completes);
      expect(workmanager.periodic, isEmpty);
    });
  });

  group('replanInBackground', () {
    final lea = Birthday(
      id: 'lea',
      name: 'Léa',
      surname: 'Martin',
      date: BirthDate.fromDate(DateTime(1994, 3, 12)),
    );
    final tom = Birthday(
      id: 'tom',
      name: 'Tom',
      surname: '',
      date: BirthDate.fromDate(DateTime(2001, 3, 2)),
    );

    late _RecordingNotificationService notifications;

    setUp(() => notifications = _RecordingNotificationService());

    // La vraie chaîne session → uid → dépôts, comme dans la tâche de fond.
    ProviderContainer makeContainer({
      User? user,
      BirthdayRepository? birthdays,
      ReminderPreferencesRepository? preferences,
      UserRepository? users,
    }) => ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        localizedNotificationStrings,
        authUserProvider.overrideWith((ref) => Stream.value(user)),
        birthdayRepositoryProvider.overrideWithValue(
          birthdays ?? _LiveBirthdayRepository([lea]),
        ),
        reminderPreferencesRepositoryProvider.overrideWithValue(
          preferences ?? RecordingReminderPreferencesRepository(),
        ),
        userRepositoryProvider.overrideWithValue(
          users ?? RecordingUserRepository(),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 3, 1, 9)),
      ],
    );

    UserRepository profileIn(String locale) => RecordingUserRepository(
      stored: UserProfile(
        id: 'u1',
        name: 'Quentin',
        surname: '',
        locale: locale,
      ),
    );

    test(
      "schedules the plan the app would, in the profile's language",
      () async {
        final birthdays = _LiveBirthdayRepository([lea]);

        await replanInBackground(
          makeContainer(
            user: MockUser(uid: 'u1'),
            birthdays: birthdays,
            users: profileIn('en'),
          ),
        );

        expect(birthdays.watchedUids, contains('u1'));
        final base = 'lea'.hashCode.abs() % 100000;
        expect(notifications.scheduled, [
          [
            ReminderNotification(
              id: base + 500000,
              daysBefore: 7,
              name: 'Léa',
              fullName: 'Léa Martin',
              age: 32,
              at: DateTime(2026, 3, 5, 10),
              payload: 'lea',
            ),
            ReminderNotification(
              id: base,
              daysBefore: 0,
              name: 'Léa',
              fullName: 'Léa Martin',
              age: 32,
              at: DateTime(2026, 3, 12, 10),
              payload: 'lea',
            ),
          ],
        ]);
        expect(notifications.strings?.channelName, 'Birthdays');
      },
    );

    test('follows the stored preferences', () async {
      await replanInBackground(
        makeContainer(
          user: MockUser(uid: 'u1'),
          preferences: RecordingReminderPreferencesRepository(
            stored: const ReminderPreferences(
              leads: {ReminderLead.sameDay},
              hour: 8,
              minute: 30,
            ),
          ),
        ),
      );

      expect(notifications.scheduled.single.map((r) => r.at), [
        DateTime(2026, 3, 12, 8, 30),
      ]);
    });

    test('keeps the former cadence when preferences fail', () async {
      await replanInBackground(
        makeContainer(
          user: MockUser(uid: 'u1'),
          preferences: _FailingPreferencesRepository(),
        ),
      );

      expect(notifications.scheduled.single.map((r) => r.at), [
        DateTime(2026, 3, 5, 10),
        DateTime(2026, 3, 12, 10),
      ]);
    });

    test('picks the language the app would show', () async {
      // Langue sans traduction : la première prise en charge, comme
      // `MaterialApp`.
      await replanInBackground(
        makeContainer(
          user: MockUser(uid: 'u1'),
          users: profileIn('de'),
        ),
      );
      expect(notifications.strings?.channelName, 'Birthdays');

      // Profil illisible : le français par défaut.
      await replanInBackground(
        makeContainer(
          user: MockUser(uid: 'u1'),
          users: _FailingUserRepository(),
        ),
      );
      expect(notifications.strings?.channelName, 'Anniversaires');
      expect(notifications.scheduled, hasLength(2));
    });

    test('leaves the reminders alone when signed out', () async {
      await replanInBackground(makeContainer());

      expect(notifications.scheduled, isEmpty);
    });

    // Une liste vide peut venir d'un cache vidé : ne rien annuler.
    test('leaves the reminders alone without any birthday', () async {
      await replanInBackground(
        makeContainer(
          user: MockUser(uid: 'u1'),
          birthdays: _LiveBirthdayRepository(const []),
        ),
      );

      expect(notifications.scheduled, isEmpty);
    });

    // L'échec remonte au dispatcher, qui rend la main à WorkManager.
    test('fails without scheduling when birthdays cannot be read', () async {
      await expectLater(
        replanInBackground(
          makeContainer(
            user: MockUser(uid: 'u1'),
            birthdays: _LiveBirthdayRepository(
              const [],
              failure: Exception('unavailable'),
            ),
          ),
        ),
        throwsA(isA<Exception>()),
      );

      expect(notifications.scheduled, isEmpty);
    });

    test('replans a birthday the app added while scheduling', () async {
      final birthdays = _LiveBirthdayRepository([lea]);
      notifications.whileScheduling = () async {
        birthdays.emit([lea, tom]);
        await Future<void>.delayed(Duration.zero);
      };

      await replanInBackground(
        makeContainer(
          user: MockUser(uid: 'u1'),
          birthdays: birthdays,
        ),
      );

      expect(notifications.scheduled, hasLength(2));
      expect(notifications.scheduled.last.map((r) => r.payload).toSet(), {
        'lea',
        'tom',
      });
    });

    test('cancels everything when the app deletes the last one', () async {
      final birthdays = _LiveBirthdayRepository([lea]);
      notifications.whileScheduling = () async {
        birthdays.emit(const []);
        await Future<void>.delayed(Duration.zero);
      };

      await replanInBackground(
        makeContainer(
          user: MockUser(uid: 'u1'),
          birthdays: birthdays,
        ),
      );

      expect(notifications.scheduled, hasLength(2));
      expect(notifications.scheduled.last, isEmpty);
    });

    test('replans with a time the app changed while scheduling', () async {
      final preferences = RecordingReminderPreferencesRepository();
      final container = makeContainer(
        user: MockUser(uid: 'u1'),
        preferences: preferences,
      );
      notifications.whileScheduling = () async {
        await preferences.savePreferences(
          'u1',
          const ReminderPreferences(
            leads: {ReminderLead.sameDay},
            hour: 8,
            minute: 30,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      };

      await replanInBackground(container);

      expect(notifications.scheduled, hasLength(2));
      expect(notifications.scheduled.last.map((r) => r.at), [
        DateTime(2026, 3, 12, 8, 30),
      ]);
    });
  });
}
