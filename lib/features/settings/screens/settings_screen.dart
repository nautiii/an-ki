import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/auth/widgets/auth_failure_text.dart';
import 'package:an_ki/features/reminders/providers/reminder_preferences_provider.dart';
import 'package:an_ki/features/reminders/widgets/reminder_preferences_tiles.dart';
import 'package:an_ki/features/reminders/widgets/reminders_tile.dart';
import 'package:an_ki/features/settings/providers/account_deletion.dart';
import 'package:an_ki/features/settings/widgets/preference_choices.dart';
import 'package:an_ki/features/settings/widgets/pseudo_field.dart';
import 'package:an_ki/features/settings/widgets/settings_section.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Réglages en blocs : le profil, les préférences appliquées dès le toucher,
/// les anniversaires (rappels, import), la sécurité quand l'appareil a une
/// empreinte, puis le compte, la suppression en dernier.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Échec d'une écriture optimiste : le profil (pseudo, thème, langue) ou
    // le réglage des rappels (cadence, heure).
    void reportFailure(AsyncValue<void>? _, AsyncValue<void> next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.errorUnknown)));
      }
    }

    ref.listen(userProfileEditorProvider, reportFailure);
    ref.listen(reminderPreferencesEditorProvider, reportFailure);
    final l10n = context.l10n;
    final hasFingerprint =
        ref.watch(fingerprintAvailableProvider).value ?? false;
    const gap = SizedBox(height: AppSpacing.lg);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            SettingsSection(
              title: l10n.settingsProfile,
              children: const [PseudoField()],
            ),
            gap,
            SettingsSection(
              title: l10n.settingsPreferences,
              children: const [ThemeChoice(), LanguageChoice()],
            ),
            gap,
            SettingsSection(
              title: l10n.settingsBirthdays,
              children: [
                // L'état des rappels, et de quoi les rétablir s'ils sont coupés.
                const RemindersTile(),
                const ReminderLeadsTile(),
                const ReminderTimeTile(),
                ListTile(
                  leading: const Icon(Icons.contact_page_rounded),
                  title: Text(l10n.importContacts),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  // L'aperçu de l'import, qui annonce lui-même ce qu'il ajoute.
                  onTap: () => context.push(AppRoutes.contactImport),
                ),
              ],
            ),
            if (hasFingerprint) ...[
              gap,
              SettingsSection(
                title: l10n.settingsSecurity,
                children: const [_BiometricSwitch()],
              ),
            ],
            gap,
            SettingsSection(
              title: l10n.settingsAccount,
              children: const [_SignOutTile(), _DeleteAccountTile()],
            ),
          ],
        ),
      ),
    );
  }
}

/// Connexion par empreinte : l'activer l'enregistre sur ce téléphone.
class _BiometricSwitch extends ConsumerWidget {
  const _BiometricSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = ref.watch(
      biometricLockProvider.select((lock) => lock.value?.enabled ?? false),
    );

    return SwitchListTile(
      title: Text(l10n.biometricConnexion),
      subtitle: Text(l10n.biometricConnexionDescription),
      secondary: const Icon(Icons.fingerprint_rounded),
      value: enabled,
      onChanged: (value) async {
        final controller = ref.read(authControllerProvider.notifier);
        final done = value
            ? await controller.enableBiometrics()
            : await controller.disableBiometrics();
        if (done && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value ? l10n.biometricEnabled : l10n.biometricDisabled,
              ),
            ),
          );
        }
      },
    );
  }
}

/// « Se déconnecter », confirmé par un dialogue. Un invité y apprend qu'il
/// perdrait ses anniversaires, et peut d'abord les sauvegarder avec Google.
class _SignOutTile extends ConsumerWidget {
  const _SignOutTile();

  /// [isAnonymous] : un invité se voit proposer de sauvegarder ses données
  /// avant de partir.
  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref, {
    required bool isAnonymous,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isAnonymous
              ? dialogContext.l10n.attention
              : dialogContext.l10n.signOut,
        ),
        content: Text(
          isAnonymous
              ? dialogContext.l10n.signOutAnonymousWarning
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
                final messenger = ScaffoldMessenger.of(context);
                final saved = context.l10n.dataSavedSuccess;
                final success = await ref
                    .read(authControllerProvider.notifier)
                    .linkWithGoogle();
                if (success) {
                  messenger.showSnackBar(SnackBar(content: Text(saved)));
                  return;
                }
                // Refusée, la sauvegarde dit pourquoi ; annulée, rien.
                if (!context.mounted) return;
                final error = ref.read(authControllerProvider).error;
                if (error != null) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(authErrorMessage(context, error))),
                  );
                }
              },
              child: Text(context.l10n.saveMyData),
            ),
          TextButton(
            onPressed: () async {
              final authController = ref.read(authControllerProvider.notifier);

              // Fermer le dialogue de confirmation
              Navigator.of(dialogContext).pop();

              // Afficher l'overlay de chargement
              if (context.mounted) {
                unawaited(
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              // Délai pour une transition visuelle fluide
              await Future<void>.delayed(const Duration(milliseconds: 600));

              // Déconnexion : les données suivent la session et se vident
              // seules.
              await authController.signOut();
            },
            child: Text(
              isAnonymous
                  ? dialogContext.l10n.deleteAndLeave
                  : dialogContext.l10n.signOut,
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Écoutée ici, la session reste à jour pour les actions du compte.
    final isAnonymous = ref.watch(isGuestProvider);

    return ListTile(
      leading: const Icon(Icons.logout_rounded),
      title: Text(context.l10n.signOut),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _confirm(context, ref, isAnonymous: isAnonymous),
    );
  }
}

/// « Supprimer mon compte », seule ligne à la couleur d'erreur : un dialogue
/// nomme la conséquence avant d'effacer les données puis le compte.
class _DeleteAccountTile extends ConsumerWidget {
  const _DeleteAccountTile();

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.deleteAccountTitle),
        content: Text(dialogContext.l10n.deleteAccountConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              final authController = ref.read(authControllerProvider.notifier);
              final accountDeletion = ref.read(
                accountDeletionProvider.notifier,
              );
              final l10n = context.l10n;

              Navigator.of(dialogContext).pop();

              var deleted = false;
              try {
                // 1. Supprimer les données Firestore
                await accountDeletion.eraseData();
                // 2. Supprimer le compte Auth
                deleted = await authController.deleteAccount();
              } catch (_) {
                // Effacement des données refusé : le compte reste.
              }
              if (!deleted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.deleteAccountError)),
                );
              }
            },
            child: Text(
              dialogContext.l10n.delete,
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = Theme.of(context).colorScheme.error;

    return ListTile(
      leading: Icon(Icons.delete_forever_rounded, color: error),
      title: Text(context.l10n.deleteAccount, style: TextStyle(color: error)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _confirm(context, ref),
    );
  }
}
