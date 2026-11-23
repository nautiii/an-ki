import 'dart:async';

import 'package:an_ki/app/bootstrap/launch_request.dart';
import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/services/app_shortcut_service.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_wishes.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Exécute ce que demandent les entrées extérieures à l'app ([LaunchRequest]),
/// notifications et raccourcis du lanceur : celle qui l'a lancée, puis celles
/// qui arrivent pendant qu'elle tourne.
///
/// Monté avec la coquille, donc seulement une fois l'app ouverte : au
/// démarrage, une requête attend la connexion et l'empreinte ; hors session,
/// celles qui arrivent sont perdues, et rien ne surgit après une inscription.
/// Une requête attend aussi que le système donne l'état de l'app : avant, Flutter ne
/// dit pas à Android qu'il gère le retour, et une page poussée là laisserait le
/// bouton retour du système fermer l'app.
/// Vit dans `app/` : il navigue entre les features.
class LaunchHandler extends ConsumerStatefulWidget {
  final Widget child;

  const LaunchHandler({super.key, required this.child});

  @override
  ConsumerState<LaunchHandler> createState() => _LaunchHandlerState();
}

class _LaunchHandlerState extends ConsumerState<LaunchHandler> {
  /// Anniversaire à souhaiter, en attendant que la liste le contienne.
  String? _wishRequest;

  /// Raccourci de module demandé, en attendant de savoir quels modules
  /// sont actifs (profil chargé).
  String? _shortcutRequest;

  StreamSubscription<NotificationTap>? _notificationTaps;
  StreamSubscription<String>? _shortcutActions;

  /// Requêtes arrivées avant que le système ne donne l'état de l'app.
  final List<LaunchRequest> _beforeLifecycle = [];
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: (_) => _flushWaiting());
    final shortcuts = ref.read(appShortcutServiceProvider);
    _shortcutActions = shortcuts.actions.listen(_onShortcut);
    final launchShortcut = shortcuts.takeLaunchAction();
    if (launchShortcut != null) {
      // Après la frame : le routeur ne se manipule pas pendant le montage.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onShortcut(launchShortcut);
      });
    }
    final notifications = ref.read(notificationServiceProvider);
    _notificationTaps = notifications.taps.listen(_onNotificationTap);
    unawaited(
      notifications.launchTap().then((tap) {
        if (tap != null && mounted) _onNotificationTap(tap);
      }),
    );
    // Au premier chargement de la liste, la personne demandée apparaît.
    ref.listenManual(
      birthdaysListProvider,
      (_, birthdays) => _fulfilWishRequest(birthdays),
    );
    // Les modules actifs connus, le raccourci demandé trouve le sien.
    ref.listenManual(
      activeModulesProvider,
      (_, active) => _fulfilShortcutRequest(active),
    );
  }

  @override
  void dispose() {
    unawaited(_notificationTaps?.cancel());
    unawaited(_shortcutActions?.cancel());
    _lifecycle.dispose();
    super.dispose();
  }

  void _onShortcut(String type) => _handle(LaunchRequest.fromShortcut(type));

  void _onNotificationTap(NotificationTap tap) {
    final request = LaunchRequest.fromNotification(tap);
    if (request != null) _handle(request);
  }

  /// Souhaiter : l'accueil, puis la feuille de partage de la personne. Sa
  /// page : par-dessus l'écran en cours, qui la montre dès qu'elle est
  /// chargée ; déjà ouverte, elle n'est pas empilée une seconde fois.
  void _handle(LaunchRequest request) {
    if (!_lifecycleKnown) {
      _beforeLifecycle.add(request);
      return;
    }
    switch (request) {
      case PersonLaunch(:final birthdayId):
        final router = GoRouter.of(context);
        final page = AppRoutes.person(birthdayId);
        // `state` : la route du dessus, poussée comprise.
        if (router.state.matchedLocation == page) return;
        unawaited(router.push(page));
      case WishLaunch(:final birthdayId):
        _wishRequest = birthdayId;
        GoRouter.of(context).go(AppRoutes.birthdays);
        _fulfilWishRequest(ref.read(birthdaysListProvider));
      case ShortcutLaunch(:final shortcutId):
        _shortcutRequest = shortcutId;
        _fulfilShortcutRequest(ref.read(activeModulesProvider));
    }
  }

  /// Vrai dès que le système a dit l'état de l'app : c'est alors seulement que
  /// WidgetsApp transmet à Android qui gère le retour (inconnu ou détachée, il
  /// ne transmet rien, et rien n'est renvoyé ensuite).
  bool get _lifecycleKnown => switch (WidgetsBinding.instance.lifecycleState) {
    null || AppLifecycleState.detached => false,
    _ => true,
  };

  void _flushWaiting() {
    if (!mounted || !_lifecycleKnown || _beforeLifecycle.isEmpty) return;
    final waiting = [..._beforeLifecycle];
    _beforeLifecycle.clear();
    waiting.forEach(_handle);
  }

  /// Exécute le raccourci demandé une fois les modules actifs connus
  /// ([active] non null) : l'onglet de son module, puis son action après la
  /// frame. Un raccourci d'un module éteint depuis, ou inconnu, est ignoré.
  void _fulfilShortcutRequest(List<AppModule>? active) {
    final shortcutId = _shortcutRequest;
    if (shortcutId == null || active == null) return;
    _shortcutRequest = null;
    for (final module in active) {
      for (final shortcut in module.shortcuts) {
        if (shortcut.id != shortcutId) continue;
        void open() {
          if (!mounted) return;
          // Une feuille ou un dialogue ouvert ne reste pas sous la nouvelle :
          // le raccourci ne les empile pas (go ne retire que les pages).
          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.settings is Page<Object?>);
          GoRouter.of(context).go(module.rootPath);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) shortcut.run(context, ref);
          });
        }

        // Les modules peuvent devenir connus pendant une construction, où le
        // routeur ne doit pas changer : après la frame, alors.
        if (SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks) {
          SchedulerBinding.instance.addPostFrameCallback((_) => open());
        } else {
          open();
        }
        return;
      }
    }
  }

  /// Souhaite la personne demandée si [birthdays] la contient ; sinon la
  /// demande attend la liste suivante (premier chargement), ou tombe si la
  /// liste chargée ne l'a pas.
  void _fulfilWishRequest(List<Birthday> birthdays) {
    final birthdayId = _wishRequest;
    if (birthdayId == null) return;
    final birthday = birthdays.where((b) => b.id == birthdayId).firstOrNull;
    if (birthday == null) {
      // La liste chargée ne l'a pas (supprimée depuis) : rien à souhaiter.
      if (ref.read(birthdaysProvider).hasValue) _wishRequest = null;
      return;
    }
    _wishRequest = null;
    // Hors du jour J et du lendemain (un raccourci épinglé, une notification
    // restée là) : sa page plutôt qu'un vœu à contretemps.
    if (!birthday.canWish(ref.read(todayProvider))) {
      // Appelé par l'écoute de la liste, qui peut tomber pendant une
      // construction où le routeur ne doit pas changer : après la frame.
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _handle(PersonLaunch(birthday.id));
        });
      } else {
        _handle(PersonLaunch(birthday.id));
      }
      return;
    }
    // Après la frame : l'accueil est affiché sous la feuille de partage.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(wishBirthday(context, birthday));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
