import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// A manual mock of [FlutterLocalNotificationsPlugin] using [Fake].
class MockNotificationsPlugin extends Fake implements FlutterLocalNotificationsPlugin {
  final List<int> cancelledIds = [];
  final List<PendingNotificationRequest> pendingRequests = [];
  final List<ZonedScheduleCall> zonedScheduleCalls = [];
  bool allCancelled = false;

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
      return Future.value(null);
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
  const MethodChannel('flutter_timezone')
      .setMockMethodCallHandler((MethodCall methodCall) async {
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
    test('scheduleAll cancels obsolete notifications and schedules new ones', () async {
      final birthdays = [
        BirthdayModel(
          id: 'birthday-1',
          uid: 'user-1',
          name: 'John',
          surname: 'Doe',
          date: DateTime(1990, 1, 1),
          categories: [],
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
    });

    test('scheduleAll handles empty list by cancelling all existing (if any)', () async {
      mockPlugin.pendingRequests.add(
        const PendingNotificationRequest(123, 'Title', 'Body', 'Payload'),
      );

      await service.scheduleAll([]);

      expect(mockPlugin.cancelledIds, contains(123));
      expect(mockPlugin.zonedScheduleCalls, isEmpty);
    });

    test('scheduled date is advanced to next year if occurrence for this year passed', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      
      final birthday = BirthdayModel(
        id: 'b1',
        uid: 'u1',
        name: 'Past',
        surname: 'Person',
        date: DateTime(1990, yesterday.month, yesterday.day),
        categories: [],
      );

      await service.scheduleAll([birthday]);

      final call = mockPlugin.zonedScheduleCalls.firstWhere((c) => c.id < 500000);
      
      expect(call.scheduledDate.year, equals(now.year + 1));
    });
  });
}
