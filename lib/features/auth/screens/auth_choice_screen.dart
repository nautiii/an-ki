import 'package:an_ki/core/animations/anki_fade_in.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthChoiceScreen extends ConsumerStatefulWidget {
  const AuthChoiceScreen({super.key});

  @override
  ConsumerState<AuthChoiceScreen> createState() => _AuthChoiceScreenState();
}

class _AuthChoiceScreenState extends ConsumerState<AuthChoiceScreen> {
  @override
  void initState() {
    super.initState();
    // Lancement automatique de la biométrie si disponible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState.canUseBiometrics) {
        _handleBiometricSignIn();
      }
    });
  }

  void _handleBiometricSignIn() async {
    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.signInWithBiometricToken(context.l10n);

    if (!mounted) return;

    if (!success) {
      final authState = ref.read(authProvider);
      // On n'affiche l'erreur que s'il y a un vrai message (pas une annulation manuelle)
      if (authState.errorMessage != null &&
          authState.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text(authState.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider.select((s) => s.isLoading));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            children: [
              const Spacer(),
              // Logo ou Illustration
              AnKiFadeIn(
                delay: const Duration(milliseconds: 100),
                child: SizedBox(
                  height: 220,
                  width: 220,
                  child: Image.asset(AppAssets.moon, fit: BoxFit.fill),
                ),
              ),
              const SizedBox(height: 8),
              AnKiFadeIn(
                delay: const Duration(milliseconds: 300),
                child: Text(
                  context.l10n.appName,
                  style: textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnKiFadeIn(
                delay: const Duration(milliseconds: 500),
                child: Text(
                  context.l10n.manageBirthdays,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              Column(
                children: [
                  AnKiFadeIn(
                    delay: const Duration(milliseconds: 700),
                    child: _AuthButton(
                      label: context.l10n.loginWithGoogle,
                      icon: Icons.login_rounded,
                      onPressed:
                          isLoading
                              ? null
                              : () => _handleGoogleSignIn(context, ref),
                      isPrimary: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnKiFadeIn(
                    delay: const Duration(milliseconds: 850),
                    child: _AuthButton(
                      label: context.l10n.loginWithEmail,
                      icon: Icons.email_outlined,
                      onPressed:
                          isLoading
                              ? null
                              : () => Navigator.of(context).pushNamed('/login'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnKiFadeIn(
                    delay: const Duration(milliseconds: 1000),
                    child: _AuthButton(
                      label: context.l10n.continueWithoutAccount,
                      icon: Icons.person_outline_rounded,
                      onPressed:
                          isLoading
                              ? null
                              : () => _handleAnonymousSignIn(context, ref),
                      isOutlined: true,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnKiFadeIn(
                    delay: const Duration(milliseconds: 1200),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.l10n.noAccountYet,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        TextButton(
                          onPressed:
                              isLoading
                                  ? null
                                  : () => Navigator.of(
                                    context,
                                  ).pushNamed('/signup'),
                          child: Text(
                            context.l10n.signUp,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _handleGoogleSignIn(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.signInWithGoogle(context.l10n);
    if (!context.mounted) return;

    if (!success) {
      final authState = ref.read(authProvider);
      if (authState.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(authState.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  void _handleAnonymousSignIn(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.signInAnonymously(context.l10n);
    if (!context.mounted) return;

    if (!success) {
      final authState = ref.read(authProvider);
      if (authState.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(authState.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } else {
      HapticFeedback.mediumImpact();
    }
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isOutlined;

  const _AuthButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isPrimary = false,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SizedBox(
        width: 280,
        height: 56,
        child:
            isOutlined
                ? OutlinedButton.icon(
                  onPressed: onPressed,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colorScheme.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    foregroundColor: colorScheme.onSurface,
                  ),
                  icon: Icon(icon, size: 20),
                  label: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                : ElevatedButton.icon(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isPrimary
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHigh,
                    foregroundColor:
                        isPrimary
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: Icon(icon, size: 20),
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
      ),
    );
  }
}
