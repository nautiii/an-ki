import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/auth/widgets/auth_failure_text.dart';
import 'package:an_ki/features/settings/widgets/delete_account_tile.dart';
import 'package:an_ki/features/settings/widgets/preference_choices.dart';
import 'package:an_ki/features/settings/widgets/pseudo_field.dart';
import 'package:an_ki/features/settings/widgets/settings_section.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Réglages en blocs : le profil, les préférences appliquées dès le toucher,
/// les sections des modules ([moduleSections]), la sécurité quand l'appareil a
/// une empreinte, puis le compte, la suppression en dernier.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.moduleSections = const []});

  /// Section de chaque module actif, dans l'ordre des modules : `app/` les
  /// branche, les Réglages ne connaissent pas les modules.
  final List<Widget> moduleSections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Échec d'une écriture optimiste du profil (pseudo, thème, langue).
    ref.listen(userProfileEditorProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.errorUnknown)));
      }
    });
    final l10n = context.l10n;
    final hasFingerprint =
        ref.watch(fingerprintAvailableProvider).value ?? false;
    const gap = SizedBox(height: AppSpacing.lg);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: SafeArea(
        top: false,
        // Une colonne plutôt qu'une liste paresseuse : la page est courte, et
        // chaque section reste montée au défilement, avec ce qu'elle écoute
        // (l'échec d'une écriture se dit même une fois la section hors écran).
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              for (final section in moduleSections) ...[gap, section],
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
                children: const [_SignOutTile(), DeleteAccountTile()],
              ),
            ],
          ),
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
