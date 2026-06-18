import 'package:an_ki/core/common/anki_text_field.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/locale_provider.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/core/theme/providers/theme_provider.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
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
    final user = ref.read(userProvider).user;
    _pseudoController = TextEditingController(text: user?.pseudo);
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService.instance.canUseFingerprint();
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

  Future<void> _handleSignOut(BuildContext context) async {
    final authState = ref.read(authProvider);
    final isAnonymous = authState.isAnonymous;

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
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
                        .read(authProvider.notifier)
                        .linkWithGoogle(context.l10n);
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
                  final authNotifier = ref.read(authProvider.notifier);
                  final userNotifier = ref.read(userProvider.notifier);
                  final birthdayNotifier = ref.read(birthdayProvider.notifier);
                  final l10n = context.l10n;

                  // Fermer le dialogue de confirmation
                  Navigator.of(dialogContext).pop();

                  // Afficher l'overlay de chargement
                  if (context.mounted) {
                    showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    );
                  }

                  // Délai pour une transition visuelle fluide
                  await Future<void>.delayed(const Duration(milliseconds: 600));

                  // Nettoyage simultané des états
                  userNotifier.clear();
                  birthdayNotifier.clear();

                  // Déconnexion finale
                  await authNotifier.signOut(l10n);
                },
                child: Text(
                  isAnonymous
                      ? dialogContext.l10n.deleteAndLeave
                      : dialogContext.l10n.signOut,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final authState = ref.read(authProvider);
    final uid = authState.user?.uid;

    if (uid == null) return;

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(dialogContext.l10n.deleteAccountTitle),
            content: Text(dialogContext.l10n.deleteAccountConfirmation),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(dialogContext.l10n.cancel),
              ),
              TextButton(
                onPressed: () async {
                  final authNotifier = ref.read(authProvider.notifier);
                  final userNotifier = ref.read(userProvider.notifier);
                  final l10n = context.l10n;

                  Navigator.of(dialogContext).pop();

                  try {
                    // 1. Supprimer les données Firestore
                    await userNotifier.deleteAccount(uid);
                    // 2. Supprimer le compte Auth
                    await authNotifier.deleteAccount(l10n);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.deleteAccountError)),
                      );
                    }
                  }
                },
                child: Text(
                  dialogContext.l10n.delete,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (!next.isAuthenticated && previous?.isAuthenticated == true) {
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLocale = ref.watch(localeProvider);
    final canUseBiometrics = ref.watch(
      authProvider.select((s) => s.canUseBiometrics),
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
                await ref.read(userProvider.notifier).updatePseudo(newPseudo);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(context.l10n.pseudoUpdated),
                    ),
                  );
                }
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
              value: canUseBiometrics,
              onChanged: (bool value) async {
                if (value) {
                  await ref.read(authProvider.notifier).enableBiometrics();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.biometricEnabled)),
                    );
                  }
                } else {
                  await ref.read(authProvider.notifier).disableBiometrics();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.biometricDisabled)),
                    );
                  }
                }
              },
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.contact_page_rounded),
            title: Text(context.l10n.importContacts),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final uid = ref.read(authProvider).user?.uid;
              if (uid == null) return;

              HapticFeedback.lightImpact();

              try {
                final count = await ref
                    .read(birthdayProvider.notifier)
                    .importFromContacts(uid);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        count > 0
                            ? context.l10n.contactsImported(count)
                            : context.l10n.noContactsWithBirthday,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(context.l10n.permissionDenied),
                    ),
                  );
                }
              }
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
                  ref.read(localeProvider.notifier).setLocale(Locale(newValue));
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
            onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: Text(context.l10n.signOut),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: () => _handleSignOut(context),
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
