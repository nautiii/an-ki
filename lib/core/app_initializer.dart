import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const AppInitializer({super.key, required this.child});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _requestNotificationPermissions();

    // Initialisation au démarrage si l'utilisateur est déjà connecté
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = ref.read(authProvider).uid;
      if (uid != null) {
        _initializeUser(uid);
      }
    });
  }

  Future<void> _requestNotificationPermissions() async {
    final granted = await NotificationService.instance.requestPermissions();
    if (!mounted) return;
    if (!granted) {
      debugPrint(
        '[AppInitializer] Permission de notifications refusée ou non accordée complètement.',
      );
    }
  }

  Future<void> _initializeUser(String uid) async {
    // Vérification de sécurité avant tout accès à 'ref'
    if (!mounted) return;

    final userNotifier = ref.read(userProvider.notifier);
    final birthdayNotifier = ref.read(birthdayProvider.notifier);

    // On lance l'écoute des anniversaires en tâche de fond pour ne pas bloquer l'UI
    Future.microtask(() => birthdayNotifier.startListening(uid));

    // Chargement de l'utilisateur Firestore
    await userNotifier.loadUser(uid);

    // Sécurité: Vérifier si le widget est toujours monté après un await
    if (!mounted) return;

    final userState = ref.read(userProvider);
    final authState = ref.read(authProvider);

    if (userState.user == null && authState.user != null) {
      final displayName = authState.user!.displayName ?? "";
      final parts = displayName.split(" ");

      await userNotifier.createUser(
        uid: uid,
        name:
            parts.isNotEmpty && parts.first.isNotEmpty
                ? parts.first
                : (authState.isAnonymous ? "Invité" : "-"),
        surname: parts.length > 1 ? parts.sublist(1).join(" ") : "",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Utilisation de ref.listen pour réagir aux changements d'état d'authentification.
    ref.listen<String?>(
      authProvider.select((s) => s.uid),
      (previous, nextUid) {
        if (nextUid != null && nextUid != previous) {
          _initializeUser(nextUid);
        }
      },
    );

    final userState = ref.watch(userProvider);

    if (userState.isLoading) {
      return const Material(child: Center(child: CircularProgressIndicator()));
    }

    return widget.child;
  }
}
