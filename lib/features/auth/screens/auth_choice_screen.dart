import 'dart:async';

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

/// Connexion d'un compte existant : ouverte depuis la bienvenue (« J'ai déjà
/// un compte »), où le retour ramène, ou seule quand l'empreinte verrouille
/// AnKi. « Déverrouiller » passe alors en tête, et l'invite s'ouvre d'elle-même
/// à l'arrivée.
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
        unawaited(_unlock());
      }
    });
  }

  /// Invite d'empreinte ; une invite fermée se relance par « Déverrouiller ».
  Future<void> _unlock() async {
    final unlocked = await ref
        .read(authControllerProvider.notifier)
        .unlockWithBiometrics(reason: context.l10n.biometricReason);
    if (unlocked && mounted) unawaited(HapticFeedback.mediumImpact());
  }

  Future<void> _signInWithGoogle() async {
    unawaited(HapticFeedback.lightImpact());
    final success = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (success && mounted) unawaited(HapticFeedback.mediumImpact());
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
    final locked = ref.watch(
      authAccessProvider.select((access) => access == AuthAccess.locked),
    );
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // Le retour vers la bienvenue, quand elle est dessous.
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        // Défile plutôt que de déborder : petit écran, grand texte.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final illustrationSize = (constraints.maxHeight * 0.25).clamp(
              96.0,
              180.0,
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.lg,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        ExcludeSemantics(
                          child: SizedBox.square(
                            dimension: illustrationSize,
                            child: Image.asset(AppAssets.moon),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.authTitle,
                            textAlign: TextAlign.center,
                            style: textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          locked ? l10n.authLockedMessage : l10n.authMessage,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const SizedBox(height: AppSpacing.xl),
                        if (locked) ...[
                          _AuthButton(
                            label: l10n.authUnlock,
                            icon: Icons.fingerprint_rounded,
                            onPressed: isLoading
                                ? null
                                : () => unawaited(_unlock()),
                            kind: _AuthButtonKind.primary,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        _AuthButton(
                          label: l10n.loginWithGoogle,
                          icon: Icons.login_rounded,
                          onPressed: isLoading
                              ? null
                              : () => unawaited(_signInWithGoogle()),
                          kind: locked
                              ? _AuthButtonKind.tonal
                              : _AuthButtonKind.primary,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _AuthButton(
                          label: l10n.loginWithEmail,
                          icon: Icons.email_outlined,
                          onPressed: isLoading
                              ? null
                              : () => context.push(AppRoutes.login),
                          kind: locked
                              ? _AuthButtonKind.outlined
                              : _AuthButtonKind.tonal,
                        ),
                        // Verrouillée, AnKi a déjà un compte sur l'appareil.
                        if (!locked) ...[
                          const SizedBox(height: AppSpacing.lg),
                          // Passe à la ligne en grand texte au lieu de déborder.
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                l10n.noAccountYet,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () => context.push(AppRoutes.signup),
                                child: Text(l10n.signUp),
                              ),
                            ],
                          ),
                        ],
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
