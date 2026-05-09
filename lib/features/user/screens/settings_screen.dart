import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/providers/theme_provider.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _pseudoController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider).user;
    _pseudoController = TextEditingController(text: user?.pseudo);
  }

  @override
  void dispose() {
    _pseudoController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final authState = ref.read(authProvider);
    final isAnonymous = authState.isAnonymous;

    await showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(isAnonymous ? "Attention" : dialogContext.l10n.signOut),
            content: Text(
              isAnonymous
                  ? "En vous déconnectant, vous perdrez tous vos anniversaires enregistrés car vous utilisez un compte invité. Voulez-vous continuer ?"
                  : dialogContext.l10n.signOutConfirmation,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(dialogContext.l10n.cancel),
              ),
              if (isAnonymous)
                TextButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    final success =
                        await ref.read(authProvider.notifier).linkWithGoogle();
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Compte sauvegardé avec succès !"),
                        ),
                      );
                    }
                  },
                  child: const Text("Sauvegarder mes données"),
                ),
              TextButton(
                onPressed: () async {
                  final authNotifier = ref.read(authProvider.notifier);
                  final userNotifier = ref.read(userProvider.notifier);
                  final birthdayNotifier = ref.read(birthdayProvider.notifier);

                  Navigator.of(dialogContext).pop();

                  userNotifier.clear();
                  birthdayNotifier.clear();

                  await authNotifier.signOut();
                },
                child: Text(
                  isAnonymous
                      ? "Supprimer et quitter"
                      : dialogContext.l10n.signOut,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state to redirect when signed out
    ref.listen(authProvider, (previous, next) {
      if (!next.isAuthenticated && previous?.isAuthenticated == true) {
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Theme changer
          SwitchListTile(
            title: Text(context.l10n.theme),
            secondary: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            ),
            value: isDark,
            onChanged: (_) => ref.read(themeProvider.notifier).toggle(context),
          ),
          const Divider(),
          // Pseudo editor
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              controller: _pseudoController,
              decoration: InputDecoration(
                labelText: context.l10n.pseudo,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPseudo = _pseudoController.text.trim();
              if (newPseudo.isNotEmpty) {
                await ref.read(userProvider.notifier).updatePseudo(newPseudo);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.pseudoUpdated)),
                  );
                }
              }
            },
            child: Text(context.l10n.updatePseudo),
          ),
          const Divider(),
          // Logout button
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: Text(context.l10n.signOut),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: () => _handleSignOut(context),
          ),
        ],
      ),
    );
  }
}
