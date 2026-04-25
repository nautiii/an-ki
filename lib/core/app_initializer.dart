import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/providers/birthday_provider.dart';
import 'package:an_ki/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

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

          // On lance les deux en parallèle
          Future.wait([
            userProvider.loadUser(uid).then((_) async {
              // Si l'utilisateur n'existe pas encore dans Firestore, on le crée
              if (userProvider.user == null) {
                final displayName = authProvider.user!.displayName ?? "";
                final parts = displayName.split(" ");
                final firstName =
                    parts.isNotEmpty && parts.first.isNotEmpty
                        ? parts.first
                        : (authProvider.isAnonymous ? "Invité" : "Prénom");
                final lastName =
                    parts.length > 1 ? parts.sublist(1).join(" ") : "Nom";

                await userProvider.createUser(
                  uid: uid,
                  name: firstName,
                  surname: lastName,
                );
              }
            }),
            Future.microtask(() => birthdayProvider.startListening()),
          ]);
        }
        // Demande les permissions push après le premier rendu
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
