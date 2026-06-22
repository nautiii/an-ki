import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/book_scanner/providers/book_scanner_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-level bootstrap widget.
///
/// Orchestrates the cross-feature startup once the user is authenticated:
/// requests notification permissions, starts the feature streams and loads
/// the Firestore user profile. It lives in the `app/` composition root because
/// it depends on multiple features — `core/` must never do that.
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
    // Keep on-device notification strings in sync with the active locale.
    NotificationService.instance.configure(
      NotificationStrings.fromL10n(context.l10n),
    );
  }

  @override
  void initState() {
    super.initState();
    _requestNotificationPermissions();

    // Initialize on startup if the user is already signed in.
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
    // Safety check before touching `ref`.
    if (!mounted) return;

    final userNotifier = ref.read(userProvider.notifier);
    final birthdayNotifier = ref.read(birthdayProvider.notifier);
    final bookScannerNotifier = ref.read(bookScannerProvider.notifier);

    // Start the birthday and book streams off the critical path so the UI is
    // not blocked while they spin up.
    Future.microtask(() {
      birthdayNotifier.startListening(uid);
      bookScannerNotifier.startListening(uid);
    });

    // Load the Firestore user.
    await userNotifier.loadUser(uid);

    // Safety: ensure the widget is still mounted after the await.
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
    // React to authentication state changes (e.g. biometric unlock).
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
