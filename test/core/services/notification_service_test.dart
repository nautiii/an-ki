import 'package:an_ki/core/services/notification_service.dart';
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
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #initialize) {
      return Future.value(true);
    }
    if (invocation.memberName == #getNotificationAppLaunchDetails) {
      return Future<NotificationAppLaunchDetails?>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class ZonedScheduleCall {
  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime scheduledDate;

  ZonedScheduleCall({
    required this.id,
    this.title,
    this.body,
    required this.scheduledDate,
  });
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
    }) => ReminderNotification(
      id: id,
      type: type,
      name: 'John',
      surname: 'Doe',
      age: 36,
      at: at ?? DateTime(2026, 6, 30, 10),
    );

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
      expect(day.body, "C'est l'anniversaire de John (36 ans) !");
      expect(weekBefore.title, '🎉 Anniversaire bientôt');
      expect(weekBefore.body, 'John Doe aura 36 ans dans 7 jours.');
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
