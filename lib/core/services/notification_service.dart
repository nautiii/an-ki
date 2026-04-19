import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Service singleton gérant les notifications locales d'anniversaire.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Constantes ────────────────────────────────────────────────────────────

  static const String _channelId = 'birthday_channel';
  static const String _channelName = 'Anniversaires';
  static const String _channelDescription = 'Rappels d\'anniversaire du jour';
  static const int _notificationHour = 8; // 08:00 chaque matin

  // ── Initialisation ────────────────────────────────────────────────────────

  /// À appeler une seule fois avant [runApp].
  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Charger toutes les zones horaires
    tz_data.initializeTimeZones();

    // 2. Positionner la zone locale du device
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    // 3. Paramètres d'init Android / iOS
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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

  /// Demande les permissions nécessaires selon la plateforme.
  Future<bool> requestPermissions() async {
    bool granted = false;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      final notifGranted =
          await android.requestNotificationsPermission() ?? false;
      final exactGranted =
          await android.requestExactAlarmsPermission() ?? false;
      granted = notifGranted && exactGranted;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (ios != null) {
      granted = await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return granted;
  }

  // ── Planification ─────────────────────────────────────────────────────────

  /// Annule tout puis replanifie une notification pour chaque anniversaire.
  Future<void> scheduleAll(List<BirthdayModel> birthdays) async {
    if (!_initialized) return;

    await _plugin.cancelAll();

    for (final birthday in birthdays) {
      await _scheduleOne(birthday);
    }

    debugPrint(
      '[NotificationService] ${birthdays.length} notification(s) planifiée(s).',
    );
  }

  Future<void> _scheduleOne(BirthdayModel birthday) async {
    try {
      final DateTime next = birthday.nextOccurrence;
      final tz.TZDateTime scheduledDate = _tzAt(next, _notificationHour);

      // Sécurité : ne pas planifier une date déjà passée
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

      final int ageAtBirthday = next.year - birthday.date.year;

      await _plugin.zonedSchedule(
        id: _notificationId(birthday.id),
        title: '🎂 ${birthday.name} ${birthday.surname}',
        body: '${birthday.name} fête ses $ageAtBirthday ans aujourd\'hui !',
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Impossible de planifier ${birthday.id}: $e',
      );
    }
  }

  // ── Utilitaires ───────────────────────────────────────────────────────────

  /// Construit un [TZDateTime] à l'heure voulue pour la date donnée.
  tz.TZDateTime _tzAt(DateTime date, int hour) =>
      tz.TZDateTime(tz.local, date.year, date.month, date.day, hour);

  /// Identifiant entier stable et unique dérivé de l'ID Firestore.
  int _notificationId(String birthdayId) =>
      birthdayId.hashCode.abs() % 100000;
}

