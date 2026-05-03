import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/core/theme/providers/theme_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Header extends ConsumerWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).user;
    final colorScheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeProvider);
    final bool isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.hello,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            Text(
              user != null ? "${user.surname} ${user.name}" : "...",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHighest,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(10),
              ),
              onPressed: () => ref.read(themeProvider.notifier).toggle(context),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder:
                    (child, animation) =>
                        RotationTransition(turns: animation, child: child),
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  key: ValueKey(isDark),
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHighest,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(10),
              ),
              onPressed: () => _handleSignOut(context, ref),
              icon: Icon(
                Icons.logout_rounded,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleSignOut(BuildContext context, WidgetRef ref) {
    final authState = ref.read(authProvider);
    final isAnonymous = authState.isAnonymous;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
              isAnonymous ? "Supprimer et quitter" : dialogContext.l10n.signOut,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
