import 'dart:ui';

import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Côté Android du plugin : l'autorisation telle que le test la règle.
class FakeAndroidNotifications extends Fake
    implements AndroidFlutterLocalNotificationsPlugin {
  bool enabled = false;

  /// Réponse de la boîte système, ou de son absence.
  bool grants = true;
  bool exactAlarms = true;
  Exception? failure;

  int requests = 0;
  int exactRequests = 0;
  int settingsOpened = 0;

  @override
  Future<bool?> areNotificationsEnabled() async {
    if (failure case final error?) throw error;
    return enabled;
  }

  @override
  Future<bool?> requestNotificationsPermission() async {
    requests++;
    if (failure case final error?) throw error;
    return enabled = grants;
  }

  @override
  Future<bool?> requestExactAlarmsPermission() async {
    exactRequests++;
    return exactAlarms;
  }

  @override
  Future<bool?> openAppNotificationSettings() async {
    settingsOpened++;
    return true;
  }
}

/// Côté iOS du plugin.
class FakeIosNotifications extends Fake
    implements IOSFlutterLocalNotificationsPlugin {
  bool enabled = false;
  bool grants = true;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<NotificationsEnabledOptions?> checkPermissions() async =>
      NotificationsEnabledOptions(
        isEnabled: enabled,
        isSoundEnabled: enabled,
        isAlertEnabled: enabled,
        isBadgeEnabled: enabled,
        isProvisionalEnabled: false,
        isCriticalEnabled: false,
        isProvidesAppNotificationSettingsEnabled: false,
      );

  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool carPlay = false,
    bool providesAppNotificationSettings = false,
  }) async {
    requests++;
    return enabled = grants;
  }

  @override
  Future<bool?> openAppNotificationSettings() async {
    settingsOpened++;
    return true;
  }
}

/// A manual mock of [FlutterLocalNotificationsPlugin] using [Fake].
class MockNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  final List<int> cancelledIds = [];
  final List<PendingNotificationRequest> pendingRequests = [];
  final List<ZonedScheduleCall> zonedScheduleCalls = [];
  bool allCancelled = false;
  bool throwOnSchedule = false;

  final android = FakeAndroidNotifications();
  final ios = FakeIosNotifications();

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() {
    if (T == AndroidFlutterLocalNotificationsPlugin) return android as T;
    if (T == IOSFlutterLocalNotificationsPlugin) return ios as T;
    return null;
  }

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
      int daysBefore, {
      int id = 1,
      DateTime? at,
      String surname = 'Doe',
    }) => ReminderNotification(
      id: id,
      daysBefore: daysBefore,
      name: 'John',
      surname: surname,
      age: 36,
      at: at ?? DateTime(2026, 6, 30, 10),
      payload: 'john',
    );

    test('adds « Souhaiter » to the notification of the day only', () async {
      await service.scheduleAll([reminder(0), reminder(7, id: 2)]);

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

      await service.scheduleAll([reminder(0)]);

      expect(
        mockPlugin.zonedScheduleCalls.single.actions!.single.title,
        'Send wishes',
      );
    });

    test('carries the payload of each reminder', () async {
      await service.scheduleAll([reminder(0), reminder(7, id: 2)]);

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

      await service.scheduleAll([reminder(0)]);

      expect(mockPlugin.cancelledIds, [999]);
    });

    test('schedules each reminder at its given local time', () async {
      await service.scheduleAll([
        reminder(0, at: DateTime(2026, 6, 30, 10)),
        reminder(7, id: 2, at: DateTime(2026, 6, 23, 10)),
      ]);

      expect(mockPlugin.zonedScheduleCalls.map((c) => c.id), [1, 2]);
      expect(mockPlugin.zonedScheduleCalls.map((c) => c.scheduledDate), [
        tz.TZDateTime(tz.local, 2026, 6, 30, 10),
        tz.TZDateTime(tz.local, 2026, 6, 23, 10),
      ]);
    });

    test('words each reminder by its days before', () async {
      await service.scheduleAll([reminder(0), reminder(7, id: 2)]);

      final [day, weekBefore] = mockPlugin.zonedScheduleCalls;
      expect(day.title, '🎂 John Doe');
      // Sans âge : le texte se répète tel quel chaque année. Le prénom en
      // tête, sans « de » à élider devant une voyelle.
      expect(day.body, 'John fête son anniversaire aujourd\'hui !');
      expect(weekBefore.title, '🎉 John Doe');
      expect(weekBefore.body, 'Dans 7 jours, John fête son anniversaire.');
    });

    test('words the day before as « Demain »', () async {
      await service.scheduleAll([reminder(1), reminder(30, id: 2)]);

      final [dayBefore, monthBefore] = mockPlugin.zonedScheduleCalls;
      expect(dayBefore.body, 'Demain, John fête son anniversaire.');
      expect(monthBefore.body, 'Dans 30 jours, John fête son anniversaire.');
      // Seul le jour J porte « Souhaiter ».
      expect(dayBefore.actions, isNull);
    });

    test('names a person without a last name with no stray space', () async {
      await service.scheduleAll([
        reminder(0, surname: ''),
        reminder(7, id: 2, surname: ''),
      ]);

      final [day, weekBefore] = mockPlugin.zonedScheduleCalls;
      expect(day.title, '🎂 John');
      expect(weekBefore.title, '🎉 John');
    });

    test('words reminders with the configured localized texts', () async {
      service.configure(
        NotificationStrings.fromL10n(
          lookupAppLocalizations(const Locale('en')),
        ),
      );

      await service.scheduleAll([reminder(0), reminder(7, id: 2)]);

      final [day, weekBefore] = mockPlugin.zonedScheduleCalls;
      expect(day.title, '🎂 John Doe');
      expect(day.body, "It's John's birthday today!");
      expect(weekBefore.title, '🎉 John Doe');
      expect(weekBefore.body, "John's birthday is in 7 days.");
      expect(
        NotificationStrings.fromL10n(lookupAppLocalizations(const Locale('en')))
            .reminderBody('John', 1),
        "John's birthday is tomorrow.",
      );
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

      await service.scheduleAll([reminder(0)]);

      expect(mockPlugin.zonedScheduleCalls, isEmpty);
    });
  });

  group('permission', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    /// `MainActivity` : Android reproposera-t-il sa boîte ?
    void rationale(bool canAskAgain) {
      messenger.setMockMethodCallHandler(
        NotificationService.permissionChannel,
        (call) async => call.method == 'canAskAgain' ? canAskAgain : null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          NotificationService.permissionChannel,
          null,
        ),
      );
    }

    void onIos() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
    }

    test('reads the permission without asking', () async {
      expect(await service.access(), NotificationAccess.denied);

      mockPlugin.android.enabled = true;
      expect(await service.access(), NotificationAccess.granted);
      expect(mockPlugin.android.requests, 0);
    });

    test('a granted request also asks for exact alarms', () async {
      expect(await service.requestAccess(), NotificationAccess.granted);
      expect(mockPlugin.android.requests, 1);
      expect(mockPlugin.android.exactRequests, 1);
    });

    test('stays granted when exact alarms are refused', () async {
      mockPlugin.android.exactAlarms = false;

      expect(await service.requestAccess(), NotificationAccess.granted);
    });

    test('a first refusal can be asked again', () async {
      mockPlugin.android.grants = false;
      rationale(true);

      expect(await service.requestAccess(), NotificationAccess.denied);
      expect(mockPlugin.android.exactRequests, 0);
    });

    test('Android blocks after a second refusal', () async {
      mockPlugin.android.grants = false;
      rationale(false);

      expect(await service.requestAccess(), NotificationAccess.blocked);
    });

    test('counts as blocked without the native rationale', () async {
      // Pas de MainActivity (canal absent) : les réglages restent sûrs.
      mockPlugin.android.grants = false;

      expect(await service.requestAccess(), NotificationAccess.blocked);
    });

    test('a failing plugin reads and asks as denied', () async {
      mockPlugin.android.failure = PlatformException(code: 'busy');

      expect(await service.access(), NotificationAccess.denied);
      expect(await service.requestAccess(), NotificationAccess.denied);
    });

    test('opens the notification settings of the app', () async {
      await service.openSettings();

      expect(mockPlugin.android.settingsOpened, 1);
    });

    test('iOS asks once: a refusal is final', () async {
      onIos();
      expect(await service.access(), NotificationAccess.denied);

      mockPlugin.ios.grants = false;
      expect(await service.requestAccess(), NotificationAccess.blocked);

      mockPlugin.ios.grants = true;
      expect(await service.requestAccess(), NotificationAccess.granted);
      expect(await service.access(), NotificationAccess.granted);
      await service.openSettings();
      expect(mockPlugin.ios.settingsOpened, 1);
    });

    test('neither reads nor asks before initialization', () async {
      final plugin = MockNotificationsPlugin()..android.enabled = true;
      final fresh = NotificationService(plugin);

      expect(await fresh.access(), NotificationAccess.denied);
      expect(await fresh.requestAccess(), NotificationAccess.denied);
      await fresh.openSettings();
      expect(plugin.android.requests, 0);
      expect(plugin.android.settingsOpened, 0);
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
