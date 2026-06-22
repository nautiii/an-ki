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
    test(
      'scheduleAll cancels obsolete notifications and schedules new ones',
      () async {
        final birthdays = [
          BirthdayReminder(
            id: 'birthday-1',
            name: 'John',
            surname: 'Doe',
            birthDate: DateTime(1990),
          ),
        ];

        mockPlugin.pendingRequests.add(
          const PendingNotificationRequest(999, 'Old', 'Body', 'Payload'),
        );

        await service.scheduleAll(birthdays);

        expect(mockPlugin.cancelledIds, contains(999));
        expect(mockPlugin.zonedScheduleCalls.length, equals(2));

        final birthdayCall = mockPlugin.zonedScheduleCalls.firstWhere(
          (c) => c.title!.contains('John Doe'),
        );
        expect(birthdayCall.body, contains('C\'est l\'anniversaire de John'));
      },
    );

    test(
      'scheduleAll handles empty list by cancelling all existing (if any)',
      () async {
        mockPlugin.pendingRequests.add(
          const PendingNotificationRequest(123, 'Title', 'Body', 'Payload'),
        );

        await service.scheduleAll([]);

        expect(mockPlugin.cancelledIds, contains(123));
        expect(mockPlugin.zonedScheduleCalls, isEmpty);
      },
    );

    test(
      'scheduled date is advanced to next year if occurrence for this year passed',
      () async {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));

        final birthday = BirthdayReminder(
          id: 'b1',
          name: 'Past',
          surname: 'Person',
          birthDate: DateTime(1990, yesterday.month, yesterday.day),
        );

        await service.scheduleAll([birthday]);

        final call = mockPlugin.zonedScheduleCalls.firstWhere(
          (c) => c.id < 500000,
        );

        expect(call.scheduledDate.year, equals(now.year + 1));
      },
    );

    test(
      'reminder is rolled to next year when the J-7 date has passed',
      () async {
        // Birthday in 2 days -> the J-7 reminder is in the past -> rolled.
        final soon = DateTime.now().add(const Duration(days: 2));
        final birthday = BirthdayReminder(
          id: 'soon',
          name: 'Soon',
          surname: 'Person',
          birthDate: DateTime(1990, soon.month, soon.day),
        );

        await service.scheduleAll([birthday]);

        final reminder = mockPlugin.zonedScheduleCalls.firstWhere(
          (c) => c.id >= 500000,
        );
        expect(
          reminder.scheduledDate.isAfter(tz.TZDateTime.now(tz.UTC)),
          isTrue,
        );
      },
    );

    test('swallows scheduling failures without throwing', () async {
      mockPlugin.throwOnSchedule = true;
      final birthday = BirthdayReminder(
        id: 'b1',
        name: 'A',
        surname: 'B',
        birthDate: DateTime(1990, 6),
      );

      await service.scheduleAll([birthday]);

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
