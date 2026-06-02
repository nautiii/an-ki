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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final authState = ref.read(authProvider);
        final userNotifier = ref.read(userProvider.notifier);
        final birthdayNotifier = ref.read(birthdayProvider.notifier);

        final uid = authState.uid;

        if (uid != null) {
          Future.wait([
            userNotifier.loadUser(uid).then((_) async {
              final userState = ref.read(userProvider);
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
            }),
            Future.microtask(() => birthdayNotifier.startListening(uid)),
          ]);
        }
        NotificationService.instance.requestPermissions().then((granted) {
          if (!granted) {
            debugPrint(
              '[AppInitializer] Permission de notifications refusée ou non accordée complètement.',
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);

    if (userState.isLoading) {
      return const Material(child: Center(child: CircularProgressIndicator()));
    }
    return widget.child;
  }
}
