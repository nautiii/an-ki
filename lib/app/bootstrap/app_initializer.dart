import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/auth/providers/sign_up_names_provider.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_model.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget de bootstrap au niveau application, monté une fois l'utilisateur
/// authentifié.
///
/// Réagit au cycle de vie de la session : demande les permissions de
/// notification, garde leurs textes dans la langue active, crée le profil
/// Firestore au premier lancement d'un compte et attend le premier profil.
/// Les données des features suivent la session seules. Il vit dans le
/// composition root `app/` car il dépend de plusieurs features — ce que
/// `core/` ne doit jamais faire.
class AppInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const AppInitializer({super.key, required this.child});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  /// Compte dont le profil est en cours de création : évite les doublons.
  String? _creatingProfileFor;

  @override
  void initState() {
    super.initState();
    unawaited(_requestNotificationPermissions());
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
    final uid = ref.read(currentUidProvider);
    final user = ref.read(authUserProvider).value;
    // Sans compte Firebase (session biométrique seule), rien à créer.
    if (uid == null || user == null || uid == _creatingProfileFor) return;
    // Le profil a pu arriver entre-temps.
    if (ref.read(userProfileProvider).value != null) return;

    _creatingProfileFor = uid;
    final typed = ref.read(signUpNamesProvider);
    final (name, surname) = typed != null
        ? (typed.name, typed.surname)
        : _namesFromDisplayName(
            user.displayName ?? '',
            fallback: user.isAnonymous ? context.l10n.guest : '-',
          );
    final profile = UserModel(
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
