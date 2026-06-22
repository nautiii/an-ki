import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Localized strings used to render scheduled notifications.
///
/// The service is context-less (a singleton), so the localized text is injected
/// from the `app/` layer via [NotificationService.configure]; the French set is
/// the fallback used before configuration runs.
class NotificationStrings {
  final String channelName;
  final String channelDescription;
  final String reminderTitle;
  final String Function(String name, int age) birthdayBody;
  final String Function(String name, String surname, int age) reminderBody;

  const NotificationStrings({
    required this.channelName,
    required this.channelDescription,
    required this.reminderTitle,
    required this.birthdayBody,
    required this.reminderBody,
  });

  static final NotificationStrings french = NotificationStrings(
    channelName: 'Anniversaires',
    channelDescription: 'Rappels d\'anniversaire du jour',
    reminderTitle: '🎉 Anniversaire bientôt',
    birthdayBody: (name, age) => 'C\'est l\'anniversaire de $name ($age ans) !',
    reminderBody:
        (name, surname, age) => '$name $surname aura $age ans dans 7 jours.',
  );

  factory NotificationStrings.fromL10n(AppLocalizations l10n) =>
      NotificationStrings(
        channelName: l10n.notificationChannelName,
        channelDescription: l10n.notificationChannelDescription,
        reminderTitle: l10n.notificationReminderTitle,
        birthdayBody: l10n.notificationBirthdayBody,
        reminderBody: l10n.notificationReminderBody,
      );
}

/// Plain value object consumed by [NotificationService.scheduleAll].
///
/// Lives in `core` so the service stays decoupled from any feature model.
/// Features map their own domain object (e.g. `BirthdayModel`) onto this type.
class BirthdayReminder {
  final String id;
  final String name;
  final String surname;
  final DateTime birthDate;

  const BirthdayReminder({
    required this.id,
    required this.name,
    required this.surname,
    required this.birthDate,
  });
}

/// Singleton service handling local birthday notifications.
class NotificationService {
  @visibleForTesting
  NotificationService(this._plugin);

  NotificationService._();

  static final NotificationService instance = NotificationService._();

  FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Constants ───────────────────────────────────────────────────────────

  static const String _channelId = 'birthday_channel';
  static const int _notificationHour = 10; // 10:00 every morning

  NotificationStrings _strings = NotificationStrings.french;

  /// Injects the localized strings used for scheduled notifications.
  void configure(NotificationStrings strings) => _strings = strings;

  // ── Initialization ────────────────────────────────────────────────────────

  /// Must be called exactly once before [runApp].
  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Load every time zone.
    tz_data.initializeTimeZones();

    // 2. Set the device's local zone.
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      debugPrint('[NotificationService] Failed to load the timezone: $e');
      tz.setLocalLocation(tz.UTC);
    }

    // 3. Android / iOS init settings.
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    _initialized = true;
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  /// Requests the permissions required for the current platform.
  Future<bool> requestPermissions() async {
    if (!_initialized) return false;

    bool granted = false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (android != null) {
        final notifGranted =
            await android.requestNotificationsPermission() ?? false;
        final exactGranted =
            await android.requestExactAlarmsPermission() ?? false;
        granted = notifGranted && exactGranted;
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios =
          _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();

      if (ios != null) {
        granted =
            await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    }

    return granted;
  }

  // ── Scheduling ──────────────────────────────────────────────────────────

  /// Refreshes the scheduled notifications for the given reminders.
  /// Cancels obsolete notifications and schedules the new or updated ones.
  Future<void> scheduleAll(List<BirthdayReminder> birthdays) async {
    if (!_initialized) return;

    final pending = await _plugin.pendingNotificationRequests();
    final currentIds = <int>{};
    for (final b in birthdays) {
      currentIds.add(_notificationId(b.id));
      currentIds.add(_reminderNotificationId(b.id));
    }

    // Only cancel what is no longer part of the current list.
    for (final p in pending) {
      if (!currentIds.contains(p.id)) {
        await _plugin.cancel(id: p.id);
      }
    }

    for (final birthday in birthdays) {
      await _scheduleBirthdayNotification(birthday);
      await _scheduleReminderNotification(birthday);
    }

    debugPrint(
      '[NotificationService] ${birthdays.length} reminder(s) processed.',
    );
  }

  Future<void> _scheduleBirthdayNotification(BirthdayReminder birthday) async {
    try {
      DateTime next = _nextOccurrence(birthday.birthDate);

      // Standard scheduling.
      tz.TZDateTime scheduledDate = _tzAt(next, _notificationHour);

      // If today's slot is already past, roll to next year.
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        next = DateTime(next.year + 1, next.month, next.day);
        scheduledDate = _tzAt(next, _notificationHour);
      }

      final int ageAtBirthday = next.year - birthday.birthDate.year;

      await _plugin.zonedSchedule(
        id: _notificationId(birthday.id),
        title: '🎂 ${birthday.name} ${birthday.surname}',
        body: _strings.birthdayBody(birthday.name, ageAtBirthday),
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Failed to schedule birthday ${birthday.id}: $e',
      );
    }
  }

  Future<void> _scheduleReminderNotification(BirthdayReminder birthday) async {
    try {
      DateTime next = _nextOccurrence(birthday.birthDate);

      // J-7
      DateTime reminderDate = next.subtract(const Duration(days: 7));

      tz.TZDateTime scheduledDate = _tzAt(reminderDate, _notificationHour);

      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        // If this year's reminder is past, schedule next year's.
        next = DateTime(next.year + 1, next.month, next.day);
        reminderDate = next.subtract(const Duration(days: 7));
        scheduledDate = _tzAt(reminderDate, _notificationHour);
      }

      final int upcomingAge = next.year - birthday.birthDate.year;

      await _plugin.zonedSchedule(
        id: _reminderNotificationId(birthday.id),
        title: _strings.reminderTitle,
        body: _strings.reminderBody(
          birthday.name,
          birthday.surname,
          upcomingAge,
        ),
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Failed to schedule reminder ${birthday.id}: $e',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Next birthday occurrence (today or in the future) for [birthDate].
  DateTime _nextOccurrence(DateTime birthDate) {
    final DateTime now = DateTime.now();
    final DateTime todayAtMidnight = DateTime(now.year, now.month, now.day);
    DateTime candidate = DateTime(now.year, birthDate.month, birthDate.day);

    if (candidate.isBefore(todayAtMidnight)) {
      candidate = DateTime(now.year + 1, birthDate.month, birthDate.day);
    }
    return candidate;
  }

  /// Builds a [TZDateTime] at the wanted hour for the given date.
  tz.TZDateTime _tzAt(DateTime date, int hour) =>
      tz.TZDateTime(tz.local, date.year, date.month, date.day, hour);

  /// Stable, unique integer id derived from the Firestore document id.
  int _notificationId(String birthdayId) => birthdayId.hashCode.abs() % 100000;

  NotificationDetails _notificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _strings.channelName,
        channelDescription: _strings.channelDescription,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  int _reminderNotificationId(String birthdayId) =>
      (_notificationId(birthdayId) + 500000);
}
