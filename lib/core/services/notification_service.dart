import 'dart:async';

import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Textes localisés utilisés pour afficher les notifications planifiées.
///
/// Le service est sans contexte (singleton) : le texte localisé est injecté
/// depuis la couche `app/` via [NotificationService.configure] ; le jeu français
/// sert de repli avant que la configuration ne soit appliquée.
class NotificationStrings {
  final String channelName;
  final String channelDescription;
  final String reminderTitle;
  // Pas d'âge dans les textes : la notification se répète chaque année avec
  // le texte écrit à la planification, l'âge serait faux l'année suivante si
  // l'app n'est pas rouverte.
  final String Function(String fullName) birthdayTitle;
  final String Function(String name) birthdayBody;
  final String Function(String fullName) reminderBody;

  /// Bouton « Souhaiter » de la notification du jour J.
  final String wishAction;

  const NotificationStrings({
    required this.channelName,
    required this.channelDescription,
    required this.reminderTitle,
    required this.birthdayTitle,
    required this.birthdayBody,
    required this.reminderBody,
    required this.wishAction,
  });

  static final NotificationStrings french = NotificationStrings(
    channelName: 'Anniversaires',
    channelDescription: 'Rappels d\'anniversaire du jour',
    reminderTitle: '🎉 Anniversaire bientôt',
    birthdayTitle: (fullName) => '🎂 $fullName',
    birthdayBody: (name) => '$name fête son anniversaire aujourd\'hui !',
    reminderBody: (fullName) => '$fullName fête son anniversaire dans 7 jours.',
    wishAction: 'Souhaiter',
  );

  factory NotificationStrings.fromL10n(AppLocalizations l10n) =>
      NotificationStrings(
        channelName: l10n.notificationChannelName,
        channelDescription: l10n.notificationChannelDescription,
        reminderTitle: l10n.notificationReminderTitle,
        birthdayTitle: l10n.notificationBirthdayTitle,
        birthdayBody: l10n.notificationBirthdayBody,
        reminderBody: l10n.notificationReminderBody,
        wishAction: l10n.wish,
      );
}

/// Autorisation d'afficher les notifications de l'app, donc les rappels.
enum NotificationAccess {
  /// Accordée : les rappels s'affichent.
  granted,

  /// Pas accordée, mais la boîte système peut encore la proposer : jamais
  /// demandée, ou refusée une seule fois sur Android.
  denied,

  /// Refusée pour de bon (deux refus sur Android, un sur iOS) ou coupée dans
  /// les réglages : seuls les réglages de l'app peuvent l'accorder.
  blocked,
}

/// Type de rappel ; il choisit le texte de la notification.
enum ReminderType { birthday, weekBefore }

/// Identifiants des boutons de notification, rendus tels quels au toucher.
abstract final class NotificationActions {
  const NotificationActions._();

  /// « Souhaiter », sur la notification du jour J.
  static const String wish = 'wish';
}

/// Toucher sur une notification de l'app : ce qu'elle porte ([payload]) et
/// le bouton touché ([actionId]), null pour la notification elle-même.
class const NotificationTap({
  required final String? payload,
  final String? actionId,
}) {
  @override
  bool operator ==(Object other) =>
      other is NotificationTap &&
      other.payload == payload &&
      other.actionId == actionId;

  @override
  int get hashCode => Object.hash(payload, actionId);
}

/// Rappel à afficher, décidé par la feature `reminders` : le service ne
/// calcule aucune date, il planifie ce qu'on lui donne.
///
/// Vit dans `core` pour que le service reste découplé de tout modèle de
/// feature ; la feature mappe son plan vers ce type.
class const ReminderNotification({
  /// Identifiant stable de la notification.
  required final int id,
  required final ReminderType type,
  required final String name,
  required final String surname,

  /// Âge atteint le jour de l'anniversaire, null si l'année de naissance est
  /// inconnue. Pas affiché tant que les notifications se répètent chaque
  /// année ; gardé pour le réafficher quand chaque occurrence sera planifiée
  /// à part.
  required final int? age,

  /// Moment du rappel, heure locale ; il se répète chaque année.
  required final DateTime at,

  /// Rendu tel quel au toucher ([NotificationTap.payload]) : l'id de
  /// l'anniversaire, que la feature choisit.
  final String? payload,
}) {
  @override
  bool operator ==(Object other) =>
      other is ReminderNotification &&
      other.id == id &&
      other.type == type &&
      other.name == name &&
      other.surname == surname &&
      other.age == age &&
      other.at == at &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(id, type, name, surname, age, at, payload);
}

/// Service singleton des notifications locales : initialisation du plugin,
/// permissions, planification des rappels qu'on lui donne. Aucune règle de
/// date ici : le quand vient de la feature `reminders`.
class NotificationService {
  @visibleForTesting
  NotificationService(this._plugin);

  NotificationService._();

  static final NotificationService instance = NotificationService._();

  FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _channelId = 'birthday_channel';

  /// Canal de `MainActivity` (Android) : le plugin ne dit pas si Android
  /// peut encore afficher sa boîte de permission après un refus.
  @visibleForTesting
  static const MethodChannel permissionChannel = MethodChannel(
    'an_ki/notification_permission',
  );

  NotificationStrings _strings = NotificationStrings.french;

  final _taps = StreamController<NotificationTap>.broadcast();

  /// Le toucher qui a lancé l'app n'est rendu qu'une fois.
  bool _launchTapTaken = false;

  /// Injecte les textes localisés utilisés pour les notifications planifiées.
  void configure(NotificationStrings strings) => _strings = strings;

  /// Touchers sur une notification pendant que l'app tourne.
  Stream<NotificationTap> get taps => _taps.stream;

  /// Toucher qui a lancé l'app, rendu une seule fois ; null si elle a démarré
  /// autrement.
  Future<NotificationTap?> launchTap() async {
    if (!_initialized || _launchTapTaken) return null;
    _launchTapTaken = true;
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details == null || !details.didNotificationLaunchApp) return null;
    if (response == null) return null;
    return NotificationTap(
      payload: response.payload,
      actionId: response.actionId,
    );
  }

  /// À appeler une seule fois avant [runApp].
  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Charger toutes les zones horaires.
    tz_data.initializeTimeZones();

    // 2. Positionner la zone locale du device.
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      debugPrint('[NotificationService] Failed to load the timezone: $e');
      tz.setLocalLocation(tz.UTC);
    }

    // 3. Paramètres d'init Android / iOS.
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
      onDidReceiveNotificationResponse: (response) => _taps.add(
        NotificationTap(payload: response.payload, actionId: response.actionId),
      ),
    );

    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  /// Autorisation actuelle, sans rien demander. Le blocage ne se révèle qu'à
  /// une demande ([requestAccess]) : avant, une autorisation absente vaut
  /// [NotificationAccess.denied].
  Future<NotificationAccess> access() async {
    if (!_initialized) return NotificationAccess.denied;
    try {
      final enabled = switch (defaultTargetPlatform) {
        TargetPlatform.android => await _android?.areNotificationsEnabled(),
        TargetPlatform.iOS => (await _ios?.checkPermissions())?.isEnabled,
        _ => null,
      };
      return enabled ?? false
          ? NotificationAccess.granted
          : NotificationAccess.denied;
    } catch (e) {
      debugPrint('[NotificationService] Failed to read the permission: $e');
      return NotificationAccess.denied;
    }
  }

  /// Demande l'autorisation : la boîte système quand elle peut encore
  /// s'afficher, sinon l'autorisation telle qu'elle est. Accordée sur
  /// Android, les alarmes exactes suivent (`USE_EXACT_ALARM` les accorde dès
  /// l'installation).
  Future<NotificationAccess> requestAccess() async {
    if (!_initialized) return NotificationAccess.denied;
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final android = _android;
          if (android == null) return NotificationAccess.denied;
          if (!(await android.requestNotificationsPermission() ?? false)) {
            return await _canAskAgain()
                ? NotificationAccess.denied
                : NotificationAccess.blocked;
          }
          if (!(await android.requestExactAlarmsPermission() ?? false)) {
            debugPrint('[NotificationService] Exact alarms not permitted.');
          }
          return NotificationAccess.granted;
        case TargetPlatform.iOS:
          final granted = await _ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          // iOS ne pose la question qu'une fois : un refus est définitif.
          return granted ?? false
              ? NotificationAccess.granted
              : NotificationAccess.blocked;
        default:
          return NotificationAccess.denied;
      }
    } catch (e) {
      debugPrint('[NotificationService] Permission request failed: $e');
      return NotificationAccess.denied;
    }
  }

  /// Après un refus, Android ne repropose sa boîte que s'il juge utile de
  /// s'expliquer (`shouldShowRequestPermissionRationale`) : un seul refus
  /// jusqu'ici. Sinon (deux refus, ou Android 12 et avant, sans boîte),
  /// seuls les réglages restent.
  Future<bool> _canAskAgain() async {
    try {
      return await permissionChannel.invokeMethod<bool>('canAskAgain') ?? false;
    } catch (e) {
      debugPrint('[NotificationService] Rationale unavailable: $e');
      return false;
    }
  }

  /// Ouvre les réglages de notification de l'app, seule issue quand
  /// l'autorisation est bloquée.
  Future<void> openSettings() async {
    if (!_initialized) return;
    try {
      final opened = switch (defaultTargetPlatform) {
        TargetPlatform.android => await _android?.openAppNotificationSettings(),
        TargetPlatform.iOS => await _ios?.openAppNotificationSettings(),
        _ => null,
      };
      if (opened != true) {
        debugPrint('[NotificationService] Settings could not be opened.');
      }
    } catch (e) {
      debugPrint('[NotificationService] Failed to open the settings: $e');
    }
  }

  /// Remplace les rappels planifiés par [reminders] : annule ceux qui n'y
  /// sont plus, planifie (ou replanifie) les autres.
  Future<void> scheduleAll(List<ReminderNotification> reminders) async {
    if (!_initialized) return;

    final ids = {for (final reminder in reminders) reminder.id};
    final pending = await _plugin.pendingNotificationRequests();
    // On n'annule que ce qui n'est plus dans la liste actuelle.
    for (final request in pending) {
      if (!ids.contains(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }

    for (final reminder in reminders) {
      await _schedule(reminder);
    }

    debugPrint(
      '[NotificationService] ${reminders.length} reminder(s) scheduled.',
    );
  }

  Future<void> _schedule(ReminderNotification reminder) async {
    // Sans espace de trop quand le nom manque (« Mamie »).
    final fullName = [
      reminder.name,
      reminder.surname,
    ].where((part) => part.isNotEmpty).join(' ');
    try {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: switch (reminder.type) {
          ReminderType.birthday => _strings.birthdayTitle(fullName),
          ReminderType.weekBefore => _strings.reminderTitle,
        },
        body: switch (reminder.type) {
          ReminderType.birthday => _strings.birthdayBody(reminder.name),
          ReminderType.weekBefore => _strings.reminderBody(fullName),
        },
        scheduledDate: tz.TZDateTime(
          tz.local,
          reminder.at.year,
          reminder.at.month,
          reminder.at.day,
          reminder.at.hour,
          reminder.at.minute,
        ),
        notificationDetails: _notificationDetails(reminder.type),
        payload: reminder.payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Failed to schedule reminder ${reminder.id}: $e',
      );
    }
  }

  NotificationDetails _notificationDetails(ReminderType type) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _strings.channelName,
        channelDescription: _strings.channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        // Le jour J, « Souhaiter » ouvre l'app sur la feuille de partage.
        // iOS n'a pas le bouton : ses catégories se déclarent à
        // l'initialisation, avant que les textes ne soient localisés.
        actions: switch (type) {
          ReminderType.birthday => [
            AndroidNotificationAction(
              NotificationActions.wish,
              _strings.wishAction,
              showsUserInterface: true,
            ),
          ],
          ReminderType.weekBefore => null,
        },
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}

/// Service de notifications de l'app. Le singleton ne sert qu'à
/// l'initialisation dans `main()` : tout le reste lit ce provider, que les
/// tests remplacent.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService.instance,
);
