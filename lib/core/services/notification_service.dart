import 'dart:async';

import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Textes localisés des notifications planifiées, dans la langue de l'app :
/// `app/` les fournit ([notificationStringsProvider]) et chaque planification
/// les reçoit ([NotificationService.scheduleAll]).
class NotificationStrings {
  final String channelName;
  final String channelDescription;
  // Pas d'âge dans les textes : la notification se répète chaque année avec
  // le texte écrit à la planification, l'âge serait faux l'année suivante si
  // l'app n'est pas rouverte.
  final String Function(String fullName) birthdayTitle;
  final String Function(String name) birthdayBody;

  /// Titre d'un rappel avant le jour J.
  final String Function(String fullName) reminderTitle;

  /// Texte d'un rappel avant le jour J : « Demain, Léa fête son
  /// anniversaire. », « Dans 7 jours, … ».
  final String Function(String name, int days) reminderBody;

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

  /// Jours de calendrier avant l'anniversaire ; 0 le jour J, qui a son
  /// texte et le bouton « Souhaiter ».
  required final int daysBefore,

  /// Prénom, en tête du texte (« Léa fête son anniversaire… »).
  required final String name,

  /// Prénom et nom réunis, en titre (« 🎂 Léa Martin »).
  required final String fullName,

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
      other.daysBefore == daysBefore &&
      other.name == name &&
      other.fullName == fullName &&
      other.age == age &&
      other.at == at &&
      other.payload == payload;

  @override
  int get hashCode =>
      Object.hash(id, daysBefore, name, fullName, age, at, payload);
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

  final _taps = StreamController<NotificationTap>.broadcast();

  /// Le toucher qui a lancé l'app n'est rendu qu'une fois.
  bool _launchTapTaken = false;

  /// Planifications en file : deux qui se chevauchent laisseraient la plus
  /// ancienne replanifier ce que la plus récente vient d'annuler.
  Future<void> _queue = Future.value();

  /// Dernier plan appliqué, ses textes et son fuseau : un plan identique ne
  /// refait pas les centaines d'appels au plugin (qui réécrit sa liste
  /// sauvegardée à chacun).
  List<ReminderNotification>? _lastPlan;
  NotificationStrings? _lastStrings;
  String? _lastZone;

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

    // 2. Positionner la zone locale du device (UTC si elle est illisible).
    tz.setLocalLocation(tz.UTC);
    await _refreshLocalZone();

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

  /// Zone locale du téléphone, relue avant chaque planification : elle a pu
  /// changer (voyage) depuis le lancement. Illisible, la zone actuelle reste.
  Future<void> _refreshLocalZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('[NotificationService] Failed to load the timezone: $e');
    }
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

  /// Remplace les rappels planifiés par [reminders], rédigés avec [strings] :
  /// annule ceux qui n'y sont plus, planifie (ou replanifie) les autres.
  /// Les appels passent l'un après l'autre ; un échec n'arrête pas les
  /// suivants.
  Future<void> scheduleAll(
    List<ReminderNotification> reminders, {
    required NotificationStrings strings,
  }) {
    final run = _queue.then((_) => _scheduleAll(reminders, strings));
    _queue = run.catchError((Object _) {});
    return run;
  }

  Future<void> _scheduleAll(
    List<ReminderNotification> reminders,
    NotificationStrings strings,
  ) async {
    if (!_initialized) return;
    await _refreshLocalZone();
    final zone = tz.local.name;
    if (identical(strings, _lastStrings) &&
        zone == _lastZone &&
        listEquals(reminders, _lastPlan)) {
      return;
    }
    // Oublié dès qu'un passage commence : interrompu (annulation refusée…),
    // il laisse le plugin entre deux plans, que le cache ne doit pas couvrir.
    _lastPlan = null;
    _lastStrings = null;
    _lastZone = null;

    final ids = {for (final reminder in reminders) reminder.id};
    final pending = await _plugin.pendingNotificationRequests();
    // On n'annule que ce qui n'est plus dans la liste actuelle.
    for (final request in pending) {
      if (!ids.contains(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }

    var allScheduled = true;
    for (final reminder in reminders) {
      allScheduled &= await _schedule(reminder, strings);
    }
    // Un rappel refusé (alarmes exactes coupées…) : le même plan sera retenté.
    if (allScheduled) {
      _lastPlan = reminders;
      _lastStrings = strings;
      _lastZone = zone;
    }

    debugPrint(
      '[NotificationService] ${reminders.length} reminder(s) scheduled.',
    );
  }

  /// Planifie [reminder] ; faux si le plugin l'a refusé.
  Future<bool> _schedule(
    ReminderNotification reminder,
    NotificationStrings strings,
  ) async {
    final isBirthday = reminder.daysBefore == 0;
    try {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: isBirthday
            ? strings.birthdayTitle(reminder.fullName)
            : strings.reminderTitle(reminder.fullName),
        body: isBirthday
            ? strings.birthdayBody(reminder.name)
            : strings.reminderBody(reminder.name, reminder.daysBefore),
        scheduledDate: tz.TZDateTime(
          tz.local,
          reminder.at.year,
          reminder.at.month,
          reminder.at.day,
          reminder.at.hour,
          reminder.at.minute,
        ),
        notificationDetails: _notificationDetails(strings, isBirthday),
        payload: reminder.payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
      return true;
    } catch (e) {
      debugPrint(
        '[NotificationService] Failed to schedule reminder ${reminder.id}: $e',
      );
      return false;
    }
  }

  NotificationDetails _notificationDetails(
    NotificationStrings strings,
    bool isBirthday,
  ) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        strings.channelName,
        channelDescription: strings.channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        // Le jour J, « Souhaiter » ouvre l'app sur la feuille de partage.
        // iOS n'a pas le bouton : ses catégories se déclarent à
        // l'initialisation, avant que les textes ne soient localisés.
        actions: isBirthday
            ? [
                AndroidNotificationAction(
                  NotificationActions.wish,
                  strings.wishAction,
                  showsUserInterface: true,
                ),
              ]
            : null,
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

/// Textes des rappels dans la langue de l'app. `app/` le remplace (elle seule
/// connaît la langue du profil) dans `main()` et dans la tâche de fond ; un
/// changement de langue replanifie donc les rappels.
final notificationStringsProvider = Provider<NotificationStrings>(
  (ref) => throw UnimplementedError(
    'notificationStringsProvider is overridden by app/.',
  ),
);
