import 'dart:async';

import 'package:an_ki/core/common/anki_text_field.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/providers/contact_import.dart';
import 'package:an_ki/features/birthday/widgets/contact_import_text.dart';
import 'package:an_ki/features/settings/providers/account_deletion.dart';
import 'package:an_ki/features/user/providers/locale_provider.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _pseudoController;
  bool _isBiometricAvailable = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProfileProvider).value;
    _pseudoController = TextEditingController(text: user?.pseudo);
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await ref
        .read(biometricServiceProvider)
        .canUseFingerprint();
    if (mounted) {
      setState(() {
        _isBiometricAvailable = available;
      });
    }
  }

  @override
  void dispose() {
    _pseudoController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut(
    BuildContext context, {
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
                final success = await ref
                    .read(authControllerProvider.notifier)
                    .linkWithGoogle();
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.dataSavedSuccess)),
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

  Future<void> _handleDeleteAccount(BuildContext context) async {
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
  Widget build(BuildContext context) {
    // Échec d'une écriture optimiste du profil (pseudo, thème, langue).
    ref.listen(userProfileEditorProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(context.l10n.errorUnknown),
          ),
        );
      }
    });
    // Issue de l'import des contacts : nombre importé, permission refusée ou
    // échec de lecture.
    ref.listen(contactImportProvider, (_, next) {
      final message = contactImportMessage(context.l10n, next);
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
        );
      }
    });

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLocale = ref.watch(localeProvider);
    // Compte anonyme : on propose de sauvegarder ses données avant de partir.
    final isAnonymous = ref.watch(
      authUserProvider.select((user) => user.value?.isAnonymous ?? false),
    );
    final biometricsEnabled = ref.watch(
      biometricLockProvider.select((lock) => lock.value?.enabled ?? false),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: AnKiTextField(
              controller: _pseudoController,
              label: context.l10n.pseudo,
              prefixIcon: Icons.alternate_email_rounded,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              final newPseudo = _pseudoController.text.trim();
              if (newPseudo.isNotEmpty) {
                // Écriture optimiste : un échec est signalé par l'écoute de
                // l'éditeur de profil.
                unawaited(
                  ref
                      .read(userProfileEditorProvider.notifier)
                      .updatePseudo(newPseudo),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text(context.l10n.pseudoUpdated),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(context.l10n.updatePseudo),
          ),
          const SizedBox(height: 16),
          const Divider(),
          if (_isBiometricAvailable) ...[
            SwitchListTile(
              title: Text(context.l10n.biometricConnexion),
              subtitle: Text(context.l10n.biometricConnexionDescription),
              secondary: const Icon(Icons.fingerprint_rounded),
              value: biometricsEnabled,
              onChanged: (bool value) async {
                final controller = ref.read(authControllerProvider.notifier);
                final done = value
                    ? await controller.enableBiometrics()
                    : await controller.disableBiometrics();
                if (done && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value
                            ? context.l10n.biometricEnabled
                            : context.l10n.biometricDisabled,
                      ),
                    ),
                  );
                }
              },
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.contact_page_rounded),
            title: Text(context.l10n.importContacts),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              unawaited(ref.read(contactImportProvider.notifier).run());
            },
          ),
          const Divider(),
          ListTile(
            title: Text(context.l10n.language),
            leading: const Icon(Icons.language_rounded),
            trailing: DropdownButton<String>(
              value: currentLocale.languageCode,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  unawaited(
                    ref
                        .read(userProfileEditorProvider.notifier)
                        .setLocale(newValue),
                  );
                }
              },
              items: const [
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              underline: const SizedBox(),
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: Text(context.l10n.theme),
            secondary: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            ),
            value: isDark,
            onChanged: (value) => unawaited(
              ref.read(userProfileEditorProvider.notifier).setDarkMode(value),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: Text(context.l10n.signOut),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: () => _handleSignOut(context, isAnonymous: isAnonymous),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.delete_forever_rounded,
              color: colorScheme.error,
            ),
            title: Text(
              context.l10n.deleteAccount,
              style: TextStyle(color: colorScheme.error),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: () => _handleDeleteAccount(context),
          ),
        ],
      ),
    );
  }
}
