import 'dart:async';

import 'package:an_ki/app/bootstrap/launch_request.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Exécute ce que demandent les entrées extérieures à l'app ([LaunchRequest]) :
/// celle qui l'a lancée, puis celles qui arrivent pendant qu'elle tourne.
///
/// Monté avec la coquille, donc seulement une fois l'app ouverte : au
/// démarrage, une requête attend la connexion et l'empreinte ; hors session,
/// celles qui arrivent sont perdues, et rien ne surgit après une inscription.
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

  StreamSubscription<NotificationTap>? _notificationTaps;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    unawaited(_notificationTaps?.cancel());
    super.dispose();
  }

  void _onNotificationTap(NotificationTap tap) {
    final request = LaunchRequest.fromNotification(tap);
    if (request != null) _handle(request);
  }

  /// Souhaiter : l'accueil, puis la feuille de partage de la personne. Sa
  /// page : par-dessus l'écran en cours, qui la montre dès qu'elle est
  /// chargée ; déjà ouverte, elle n'est pas empilée une seconde fois.
  void _handle(LaunchRequest request) {
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
    }
  }

  /// Souhaite la personne demandée si [birthdays] la contient ; sinon la
  /// demande attend la liste suivante (premier chargement).
  void _fulfilWishRequest(List<Birthday> birthdays) {
    final birthdayId = _wishRequest;
    if (birthdayId == null) return;
    final birthday = birthdays.where((b) => b.id == birthdayId).firstOrNull;
    if (birthday == null) return;
    _wishRequest = null;
    // Après la frame : l'accueil est affiché sous la feuille de partage.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(wishBirthday(context, birthday));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
