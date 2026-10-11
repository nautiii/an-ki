import 'dart:async';

import 'package:an_ki/core/animations/anki_fade_in.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/domain/biometric_lock.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/auth/widgets/auth_failure_text.dart';
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
    // App verrouillée par l'empreinte : l'invite s'ouvre d'elle-même.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(authAccessProvider) == AuthAccess.locked) {
        _handleBiometricSignIn();
      }
    });
  }

  void _handleBiometricSignIn() async {
    final unlocked = await ref
        .read(authControllerProvider.notifier)
        .unlockWithBiometrics();
    if (unlocked && mounted) unawaited(HapticFeedback.mediumImpact());
  }

  /// Échec d'une connexion lancée ici ; un écran poussé au-dessus (connexion
  /// par e-mail) annonce les siens.
  void _onAuthResult(AsyncValue<void>? _, AsyncValue<void> next) {
    if (next case AsyncError(:final error)) {
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(authErrorMessage(context, error)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, _onAuthResult);
    final isLoading = ref.watch(
      authControllerProvider.select((s) => s.isLoading),
    );
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
                      onPressed: isLoading
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
                      onPressed: isLoading
                          ? null
                          : () =>
                                Navigator.of(context)
                                    .pushNamed(AppRoutes.login),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnKiFadeIn(
                    delay: const Duration(milliseconds: 1000),
                    child: _AuthButton(
                      label: context.l10n.continueWithoutAccount,
                      icon: Icons.person_outline_rounded,
                      onPressed: isLoading
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
                          onPressed: isLoading
                              ? null
                              : () =>
                                    Navigator.of(context)
                                        .pushNamed(AppRoutes.signup),
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
    unawaited(HapticFeedback.lightImpact());
    final success = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (success && context.mounted) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  void _handleAnonymousSignIn(BuildContext context, WidgetRef ref) async {
    unawaited(HapticFeedback.lightImpact());
    final success = await ref
        .read(authControllerProvider.notifier)
        .signInAnonymously();
    if (success && context.mounted) {
      unawaited(HapticFeedback.mediumImpact());
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
        child: isOutlined
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
                  backgroundColor: isPrimary
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHigh,
                  foregroundColor: isPrimary
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
