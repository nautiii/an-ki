import 'dart:ui';

import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// A manual mock of [FlutterLocalNotificationsPlugin] using [Fake].
class MockNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  final List<int> cancelledIds = [];
  final List<PendingNotificationRequest> pendingRequests = [];
  final List<ZonedScheduleCall> zonedScheduleCalls = [];
  bool allCancelled = false;
  bool throwOnSchedule = false;

  /// Rappel du plugin pour un toucher pendant que l'app tourne.
  DidReceiveNotificationResponseCallback? onResponse;

  /// Ce que le plugin dit du lancement de l'app.
  NotificationAppLaunchDetails? launchDetails;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    onResponse = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => launchDetails;

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> cancelAll() async {
    allCancelled = true;
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return pendingRequests;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (throwOnSchedule) throw Exception('schedule failed');
    zonedScheduleCalls.add(
      ZonedScheduleCall(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        details: notificationDetails,
        payload: payload,
      ),
    );
  }
}

class ZonedScheduleCall {
  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime scheduledDate;
  final NotificationDetails details;
  final String? payload;

  ZonedScheduleCall({
    required this.id,
    this.title,
    this.body,
    required this.scheduledDate,
    required this.details,
    this.payload,
  });

  /// Boutons Android de la notification.
  List<AndroidNotificationAction>? get actions => details.android?.actions;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the flutter_timezone channel
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_timezone'), (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'getLocalTimezone') {
          return 'UTC';
        }
        return null;
      });

  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.UTC);

  late NotificationService service;
  late MockNotificationsPlugin mockPlugin;

  setUp(() async {
    mockPlugin = MockNotificationsPlugin();
    service = NotificationService(mockPlugin);
    await service.initialize();
  });

  group('NotificationService', () {
    ReminderNotification reminder(
      ReminderType type, {
      int id = 1,
      DateTime? at,
      String surname = 'Doe',
    }) => ReminderNotification(
      id: id,
      type: type,
      name: 'John',
      surname: surname,
      age: 36,
      at: at ?? DateTime(2026, 6, 30, 10),
      payload: 'john',
    );

    test('adds « Souhaiter » to the notification of the day only', () async {
      await service.scheduleAll([
        reminder(ReminderType.birthday),
        reminder(ReminderType.weekBefore, id: 2),
      ]);

      final [day, weekBefore] = mockPlugin.zonedScheduleCalls;
      final wish = day.actions!.single;
      expect(wish.id, NotificationActions.wish);
      expect(wish.title, 'Souhaiter');
      // Le bouton ouvre l'app, qui affiche la feuille de partage.
      expect(wish.showsUserInterface, isTrue);
      expect(weekBefore.actions, isNull);
    });

    test('names the wish button in the configured language', () async {
      service.configure(
        NotificationStrings.fromL10n(
          lookupAppLocalizations(const Locale('en')),
        ),
      );

      await service.scheduleAll([reminder(ReminderType.birthday)]);

      expect(
        mockPlugin.zonedScheduleCalls.single.actions!.single.title,
        'Send wishes',
      );
    });

    test('carries the payload of each reminder', () async {
      await service.scheduleAll([
        reminder(ReminderType.birthday),
        reminder(ReminderType.weekBefore, id: 2),
      ]);

      expect(mockPlugin.zonedScheduleCalls.map((c) => c.payload), [
        'john',
        'john',
      ]);
    });

    test('cancels the notifications no longer planned', () async {
      mockPlugin.pendingRequests.addAll(const [
        PendingNotificationRequest(1, 'Kept', 'Body', 'Payload'),
        PendingNotificationRequest(999, 'Old', 'Body', 'Payload'),
      ]);

      await service.scheduleAll([reminder(ReminderType.birthday)]);

      expect(mockPlugin.cancelledIds, [999]);
    });

    test('schedules each reminder at its given local time', () async {
      await service.scheduleAll([
        reminder(ReminderType.birthday, at: DateTime(2026, 6, 30, 10)),
        reminder(ReminderType.weekBefore, id: 2, at: DateTime(2026, 6, 23, 10)),
      ]);

      expect(mockPlugin.zonedScheduleCalls.map((c) => c.id), [1, 2]);
      expect(mockPlugin.zonedScheduleCalls.map((c) => c.scheduledDate), [
        tz.TZDateTime(tz.local, 2026, 6, 30, 10),
        tz.TZDateTime(tz.local, 2026, 6, 23, 10),
      ]);
    });

    test('words each reminder by its type', () async {
      await service.scheduleAll([
        reminder(ReminderType.birthday),
        reminder(ReminderType.weekBefore, id: 2),
      ]);

      final [day, weekBefore] = mockPlugin.zonedScheduleCalls;
      expect(day.title, '🎂 John Doe');
      // Sans âge : le texte se répète tel quel chaque année.
      expect(day.body, "C'est l'anniversaire de John aujourd'hui !");
      expect(weekBefore.title, '🎉 Anniversaire bientôt');
      expect(weekBefore.body, 'John Doe fête son anniversaire dans 7 jours.');
    });

    test('names a person without a last name with no stray space', () async {
      await service.scheduleAll([
        reminder(ReminderType.birthday, surname: ''),
        reminder(ReminderType.weekBefore, id: 2, surname: ''),
      ]);

      final [day, weekBefore] = mockPlugin.zonedScheduleCalls;
      expect(day.title, '🎂 John');
      expect(weekBefore.body, 'John fête son anniversaire dans 7 jours.');
    });

    test('words reminders with the configured localized texts', () async {
      service.configure(
        NotificationStrings.fromL10n(
          lookupAppLocalizations(const Locale('en')),
        ),
      );

      await service.scheduleAll([
        reminder(ReminderType.birthday),
        reminder(ReminderType.weekBefore, id: 2),
      ]);

      final [day, weekBefore] = mockPlugin.zonedScheduleCalls;
      expect(day.body, "It's John's birthday today!");
      expect(weekBefore.title, '🎉 Birthday soon');
      expect(weekBefore.body, "John Doe's birthday is in 7 days.");
    });

    test('an empty list cancels every pending notification', () async {
      mockPlugin.pendingRequests.add(
        const PendingNotificationRequest(123, 'Title', 'Body', 'Payload'),
      );

      await service.scheduleAll([]);

      expect(mockPlugin.cancelledIds, contains(123));
      expect(mockPlugin.zonedScheduleCalls, isEmpty);
    });

    test('swallows scheduling failures without throwing', () async {
      mockPlugin.throwOnSchedule = true;

      await service.scheduleAll([reminder(ReminderType.birthday)]);

      expect(mockPlugin.zonedScheduleCalls, isEmpty);
    });
  });

  group('taps', () {
    const wishResponse = NotificationResponse(
      notificationResponseType:
          NotificationResponseType.selectedNotificationAction,
      actionId: NotificationActions.wish,
      payload: 'lea',
    );

    test('forwards a tap while the app runs', () async {
      final taps = <NotificationTap>[];
      final subscription = service.taps.listen(taps.add);
      addTearDown(subscription.cancel);

      mockPlugin.onResponse!(wishResponse);
      await Future<void>.delayed(Duration.zero);

      expect(taps, [
        const NotificationTap(
          payload: 'lea',
          actionId: NotificationActions.wish,
        ),
      ]);
    });

    test('gives the tap that launched the app, once', () async {
      mockPlugin.launchDetails = const NotificationAppLaunchDetails(
        true,
        notificationResponse: wishResponse,
      );

      expect(
        await service.launchTap(),
        const NotificationTap(
          payload: 'lea',
          actionId: NotificationActions.wish,
        ),
      );
      expect(await service.launchTap(), isNull);
    });

    test('gives no launch tap when the app started otherwise', () async {
      mockPlugin.launchDetails = const NotificationAppLaunchDetails(false);

      expect(await service.launchTap(), isNull);
    });

    test('gives no launch tap before initialization', () async {
      final fresh = NotificationService(MockNotificationsPlugin());

      expect(await fresh.launchTap(), isNull);
    });
  });

  test('initialize falls back to UTC when the timezone lookup fails', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          (call) async => throw PlatformException(code: 'no-tz'),
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_timezone'),
            (call) async => 'UTC',
          );
    });

    final freshService = NotificationService(MockNotificationsPlugin());

    await expectLater(freshService.initialize(), completes);
  });
}
