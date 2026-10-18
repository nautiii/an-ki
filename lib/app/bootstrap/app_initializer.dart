import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/auth/providers/sign_up_names_provider.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_wish.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Widget de bootstrap au niveau application, monté une fois l'utilisateur
/// authentifié.
///
/// Réagit au cycle de vie de la session : demande les permissions de
/// notification, garde leurs textes dans la langue active, crée le profil
/// Firestore au premier lancement d'un compte et attend le premier profil.
/// Le bouton « Souhaiter » d'une notification ramène à l'accueil et ouvre la
/// feuille de partage dès que la personne est chargée. Les données des
/// features suivent la session seules. Il vit dans le composition root
/// `app/` car il dépend de plusieurs features — ce que `core/` ne doit
/// jamais faire.
class AppInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const AppInitializer({super.key, required this.child});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  /// Compte dont le profil est en cours de création : évite les doublons.
  String? _creatingProfileFor;

  /// Anniversaire à souhaiter, demandé par une notification, en attendant
  /// que la liste le contienne.
  String? _wishRequest;

  StreamSubscription<NotificationTap>? _notificationTaps;

  @override
  void initState() {
    super.initState();
    unawaited(_requestNotificationPermissions());
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
    // Premier lancement d'un compte : pas encore de profil, on le crée (après
    // la frame, pour disposer du contexte et de la langue).
    ref.listenManual(userProfileProvider, fireImmediately: true, (_, next) {
      if (next case AsyncData(value: null)) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(_createMissingProfile()),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Garde les textes des notifications locales synchronisés avec la locale active.
    ref
        .read(notificationServiceProvider)
        .configure(NotificationStrings.fromL10n(context.l10n));
  }

  @override
  void dispose() {
    unawaited(_notificationTaps?.cancel());
    super.dispose();
  }

  /// « Souhaiter » sur une notification : l'accueil, puis la feuille de
  /// partage de la personne. Toucher la notification elle-même ouvre
  /// simplement l'app.
  void _onNotificationTap(NotificationTap tap) {
    final birthdayId = tap.payload;
    if (tap.actionId != NotificationActions.wish || birthdayId == null) return;
    _wishRequest = birthdayId;
    GoRouter.of(context).go(AppRoutes.birthdays);
    _fulfilWishRequest(ref.read(birthdaysListProvider));
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

  Future<void> _requestNotificationPermissions() async {
    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermissions();
    if (!mounted) return;
    if (!granted) {
      debugPrint(
        '[AppInitializer] Notification permission denied or only partially granted.',
      );
    }
  }

  /// Crée le profil du compte courant s'il n'existe pas encore : noms saisis
  /// à l'inscription, sinon tirés du compte Google, sinon « Invité ».
  Future<void> _createMissingProfile() async {
    if (!mounted) return;
    final user = ref.read(authUserProvider).value;
    if (user == null || user.uid == _creatingProfileFor) return;
    // Le profil a pu arriver entre-temps.
    if (ref.read(userProfileProvider).value != null) return;

    final uid = user.uid;
    _creatingProfileFor = uid;
    final typed = ref.read(signUpNamesProvider);
    final (name, surname) = typed != null
        ? (typed.name, typed.surname)
        : _namesFromDisplayName(
            user.displayName ?? '',
            fallback: user.isAnonymous ? context.l10n.guest : '-',
          );
    final profile = UserProfile(
      id: uid,
      name: name,
      surname: surname,
      isDark: MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      locale: 'fr',
    );
    final users = ref.read(userRepositoryProvider);
    final signUpNames = ref.read(signUpNamesProvider.notifier);
    try {
      // Transaction « créer si absent » : n'écrase jamais un profil existant.
      await users.createUser(profile);
      signUpNames.clear();
    } catch (error) {
      debugPrint('[AppInitializer] profile creation failed: $error');
      // Permet une nouvelle tentative au prochain profil vide.
      if (mounted) _creatingProfileFor = null;
    }
  }

  /// Sépare « Prénom Nom… » ; [fallback] quand le nom affiché est vide.
  static (String, String) _namesFromDisplayName(
    String displayName, {
    required String fallback,
  }) {
    final parts = displayName.split(' ');
    return (
      parts.first.isNotEmpty ? parts.first : fallback,
      parts.length > 1 ? parts.sublist(1).join(' ') : '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      userProfileProvider.select(
        (profile) => profile.isLoading && !profile.hasValue,
      ),
    );

    if (isLoading) {
      return const Material(child: Center(child: CircularProgressIndicator()));
    }

    return widget.child;
  }
}
