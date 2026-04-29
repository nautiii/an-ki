import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/providers/auth_provider.dart';
import 'package:an_ki/providers/birthday_provider.dart';
import 'package:an_ki/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppInitializer extends StatefulWidget {
  final StatefulWidget child;

  const AppInitializer({super.key, required this.child});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        final userProvider = context.read<UserProvider>();
        final birthdayProvider = context.read<BirthdayProvider>();

        if (authProvider.user != null) {
          final uid = authProvider.user!.uid;

          Future.wait([
            userProvider.loadUser(uid).then((_) async {
              if (userProvider.user == null) {
                final displayName = authProvider.user!.displayName ?? "";
                final parts = displayName.split(" ");

                await userProvider.createUser(
                  uid: uid,
                  name:
                      parts.isNotEmpty && parts.first.isNotEmpty
                          ? parts.first
                          : (authProvider.isAnonymous ? "Invité" : "Prénom"),
                  surname:
                      parts.length > 1 ? parts.sublist(1).join(" ") : "Nom",
                );
              }
            }),
            Future.microtask(() => birthdayProvider.startListening(uid)),
          ]);
        }
        NotificationService.instance.requestPermissions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final UserProvider userProvider = context.watch<UserProvider>();

    if (userProvider.isLoading) {
      return const Material(child: Center(child: CircularProgressIndicator()));
    }
    return widget.child;
  }
}
