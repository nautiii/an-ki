import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget de bootstrap au niveau application.
///
/// Orchestre le démarrage transverse une fois l'utilisateur authentifié :
/// demande les permissions de notification, lance les streams des features et
/// charge le profil utilisateur Firestore. Il vit dans le composition root
/// `app/` car il dépend de plusieurs features — ce que `core/` ne doit jamais faire.
class AppInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const AppInitializer({super.key, required this.child});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Garde les textes des notifications locales synchronisés avec la locale active.
    NotificationService.instance.configure(
      NotificationStrings.fromL10n(context.l10n),
    );
  }

  @override
  void initState() {
    super.initState();
    _requestNotificationPermissions();

    // Initialisation au démarrage si l'utilisateur est déjà connecté.
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
        '[AppInitializer] Notification permission denied or only partially granted.',
      );
    }
  }

  Future<void> _initializeUser(String uid) async {
    // Vérification de sécurité avant tout accès à `ref`.
    if (!mounted) return;

    final userNotifier = ref.read(userProvider.notifier);
    final birthdayNotifier = ref.read(birthdayProvider.notifier);
    final bookScannerNotifier = ref.read(bookScannerProvider.notifier);

    // Lance les streams anniversaires et livres hors du chemin critique pour ne
    // pas bloquer l'UI pendant leur démarrage.
    Future.microtask(() {
      birthdayNotifier.startListening(uid);
      bookScannerNotifier.startListening(uid);
    });

    // Chargement de l'utilisateur Firestore.
    await userNotifier.loadUser(uid);

    // Sécurité : vérifier que le widget est toujours monté après l'await.
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
                : (authState.isAnonymous ? context.l10n.guest : "-"),
        surname: parts.length > 1 ? parts.sublist(1).join(" ") : "",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Réagit aux changements d'état d'authentification (ex. déverrouillage biométrique).
    ref.listen<String?>(authProvider.select((s) => s.uid), (previous, nextUid) {
      if (nextUid != null && nextUid != previous) {
        _initializeUser(nextUid);
      }
    });

    final isLoading = ref.watch(userProvider.select((s) => s.isLoading));

    if (isLoading) {
      return const Material(child: Center(child: CircularProgressIndicator()));
    }

    return widget.child;
  }
}
