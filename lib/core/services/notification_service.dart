import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/features/birthday/data/models/birthday_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Service singleton gérant les notifications locales d'anniversaire.
class NotificationService {
  @visibleForTesting
  NotificationService(this._plugin);

  NotificationService._();

  static final NotificationService instance = NotificationService._();

  FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Constantes ────────────────────────────────────────────────────────────

  static const String _channelId = 'birthday_channel';
  static const String _channelName = 'Anniversaires';
  static const String _channelDescription = 'Rappels d\'anniversaire du jour';
  static const int _notificationHour = 10; // 10:00 chaque matin

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
    } catch (e) {
      debugPrint(
        '[NotificationService] Erreur lors du chargement de la timezone : $e',
      );
      tz.setLocalLocation(tz.UTC);
    }

    // 3. Paramètres d'init Android / iOS
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

  /// Demande les permissions nécessaires selon la plateforme.
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

  // ── Planification ─────────────────────────────────────────────────────────

  /// Met à jour les notifications planifiées pour les anniversaires donnés.
  /// Supprime les notifications obsolètes et planifie les nouvelles ou mises à jour.
  Future<void> scheduleAll(List<BirthdayModel> birthdays) async {
    if (!_initialized) return;

    final pending = await _plugin.pendingNotificationRequests();
    final currentIds = <int>{};
    for (final b in birthdays) {
      currentIds.add(_notificationId(b.id));
      currentIds.add(_reminderNotificationId(b.id));
    }

    // On n'annule que ce qui n'est plus dans la liste actuelle
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
      '[NotificationService] ${birthdays.length} anniversaire(s) traité(s).',
    );
  }

  Future<void> _scheduleBirthdayNotification(BirthdayModel birthday) async {
    try {
      DateTime next = birthday.nextOccurrence;

      // Planification standard
      tz.TZDateTime scheduledDate = _tzAt(next, _notificationHour);

      // Si l'heure prévue pour aujourd'hui est déjà passée, on passe à l'année prochaine
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        next = DateTime(next.year + 1, next.month, next.day);
        scheduledDate = _tzAt(next, _notificationHour);
      }

      final int ageAtBirthday = next.year - birthday.date.year;

      await _plugin.zonedSchedule(
        id: _notificationId(birthday.id),
        title: '🎂 ${birthday.name} ${birthday.surname}',
        body:
            'C\'est l\'anniversaire de ${birthday.name} ($ageAtBirthday ans) !',
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Impossible de planifier anniversaire ${birthday.id}: $e',
      );
    }
  }

  Future<void> _scheduleReminderNotification(BirthdayModel birthday) async {
    try {
      DateTime next = birthday.nextOccurrence;

      // J-7
      DateTime reminderDate = next.subtract(const Duration(days: 7));

      tz.TZDateTime scheduledDate = _tzAt(reminderDate, _notificationHour);

      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        // Si le rappel de cette année est passé, on planifie celui de l'année prochaine
        next = DateTime(next.year + 1, next.month, next.day);
        reminderDate = next.subtract(const Duration(days: 7));
        scheduledDate = _tzAt(reminderDate, _notificationHour);
      }

      final int upcomingAge = next.year - birthday.date.year;

      await _plugin.zonedSchedule(
        id: _reminderNotificationId(birthday.id),
        title: '🎉 Anniversaire bientôt',
        body:
            '${birthday.name} ${birthday.surname} aura $upcomingAge ans dans 7 jours.',
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Impossible de planifier rappel ${birthday.id}: $e',
      );
    }
  }

  // ── Utilitaires ───────────────────────────────────────────────────────────

  /// Construit un [TZDateTime] à l'heure voulue pour la date donnée.
  tz.TZDateTime _tzAt(DateTime date, int hour) =>
      tz.TZDateTime(tz.local, date.year, date.month, date.day, hour);

  /// Identifiant entier stable et unique dérivé de l'ID Firestore.
  int _notificationId(String birthdayId) => birthdayId.hashCode.abs() % 100000;

  NotificationDetails _notificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
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
