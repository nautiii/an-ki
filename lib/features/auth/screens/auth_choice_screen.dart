import 'dart:async';

import 'package:an_ki/core/animations/anki_fade_in.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/domain/biometric_lock.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/auth/widgets/auth_failure_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        .unlockWithBiometrics(reason: context.l10n.biometricReason);
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
        // Défile plutôt que de déborder : petit écran, grand texte.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final illustrationSize = (constraints.maxHeight * 0.3).clamp(
              120.0,
              220.0,
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 2 * AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox.shrink(),
                    Column(
                      children: [
                        AnKiFadeIn(
                          delay: const Duration(milliseconds: 100),
                          child: ExcludeSemantics(
                            child: SizedBox.square(
                              dimension: illustrationSize,
                              child: Image.asset(
                                AppAssets.moon,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        AnKiFadeIn(
                          delay: const Duration(milliseconds: 300),
                          child: Text(
                            context.l10n.appName,
                            textAlign: TextAlign.center,
                            style: textTheme.headlineLarge?.copyWith(
                              color: colorScheme.primary,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
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
                      ],
                    ),
                    Column(
                      children: [
                        const SizedBox(height: AppSpacing.xl),
                        AnKiFadeIn(
                          delay: const Duration(milliseconds: 700),
                          child: _AuthButton(
                            label: context.l10n.loginWithGoogle,
                            icon: Icons.login_rounded,
                            onPressed: isLoading
                                ? null
                                : () => _handleGoogleSignIn(context, ref),
                            kind: _AuthButtonKind.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AnKiFadeIn(
                          delay: const Duration(milliseconds: 850),
                          child: _AuthButton(
                            label: context.l10n.loginWithEmail,
                            icon: Icons.email_outlined,
                            onPressed: isLoading
                                ? null
                                : () => context.go(AppRoutes.login),
                            kind: _AuthButtonKind.tonal,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AnKiFadeIn(
                          delay: const Duration(milliseconds: 1000),
                          child: _AuthButton(
                            label: context.l10n.continueWithoutAccount,
                            icon: Icons.person_outline_rounded,
                            onPressed: isLoading
                                ? null
                                : () => _handleAnonymousSignIn(context, ref),
                            kind: _AuthButtonKind.outlined,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AnKiFadeIn(
                          delay: const Duration(milliseconds: 1200),
                          // Passe à la ligne en grand texte au lieu de déborder.
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                context.l10n.noAccountYet,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () => context.go(AppRoutes.signup),
                                child: Text(context.l10n.signUp),
                              ),
                            ],
                          ),
                        ),
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.md),
                            child: SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
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

enum _AuthButtonKind { primary, tonal, outlined }

/// Bouton de connexion pleine largeur (bornée) : style du thème, hauteur
/// libre pour que le libellé passe à la ligne en grand texte.
class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.icon,
    required this.kind,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final _AuthButtonKind kind;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, textAlign: TextAlign.center);
    final iconWidget = Icon(icon);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: SizedBox(
        width: double.infinity,
        child: switch (kind) {
          _AuthButtonKind.primary => FilledButton.icon(
            onPressed: onPressed,
            icon: iconWidget,
            label: text,
          ),
          _AuthButtonKind.tonal => FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: iconWidget,
            label: text,
          ),
          _AuthButtonKind.outlined => OutlinedButton.icon(
            onPressed: onPressed,
            icon: iconWidget,
            label: text,
          ),
        },
      ),
    );
  }
}
