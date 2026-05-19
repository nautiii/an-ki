import 'package:an_ki/core/animations/anki_fade_in.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthChoicePage extends ConsumerStatefulWidget {
  const AuthChoicePage({super.key});

  @override
  ConsumerState<AuthChoicePage> createState() => _AuthChoicePageState();
}

class _AuthChoicePageState extends ConsumerState<AuthChoicePage> {
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
    final success = await authNotifier.signInWithBiometrics(context);

    if (!mounted) return;

    if (!success) {
      final authState = ref.read(authProvider);
      // On n'affiche l'erreur que s'il y a un vrai message (pas une annulation manuelle)
      if (authState.errorMessage != null && authState.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final authState = ref.watch(authProvider);
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
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 50,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
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
                          authState.isLoading
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
                          authState.isLoading
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
                          authState.isLoading
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
                              authState.isLoading
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
              if (authState.isLoading)
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
    final success = await authNotifier.signInWithGoogle();
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
    final success = await authNotifier.signInAnonymously();
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

    if (isOutlined) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colorScheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            foregroundColor: colorScheme.onSurface,
          ),
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHigh,
          foregroundColor:
              isPrimary ? colorScheme.onPrimary : colorScheme.onSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
    );
  }
}
