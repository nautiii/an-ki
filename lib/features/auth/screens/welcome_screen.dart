import 'dart:async';

import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/auth/widgets/auth_failure_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bienvenue, hors session : la promesse d'AnKi et une seule décision.
///
/// « Commencer » ouvre AnKi sans compte (un compte anonyme, à sauvegarder
/// plus tard) : la valeur d'abord, le compte ensuite. « J'ai déjà un compte »
/// ouvre la connexion par-dessus ; le retour revient ici.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Échec de « Commencer » (hors ligne…). La connexion ouverte par-dessus
    // annonce les siens.
    ref.listen(authControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(context, error))),
        );
      }
    });
    final starting = ref.watch(
      authControllerProvider.select((state) => state.isLoading),
    );
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final screen = Scaffold(
      body: SafeArea(
        // Défile plutôt que de déborder : petit écran, grand texte.
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Assez bas pour garder les deux actions visibles en 360×640.
            final heroHeight = (constraints.maxHeight * 0.3).clamp(
              144.0,
              320.0,
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 2 * AppSpacing.lg,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _NightHero(height: heroHeight),
                        const SizedBox(height: AppSpacing.lg),
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.welcomeTitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.welcomeMessage,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.lg),
                        // Le libellé reste pendant l'attente : TalkBack lit
                        // toujours « Commencer ».
                        FilledButton.icon(
                          onPressed: starting
                              ? null
                              : () => unawaited(_start(ref)),
                          icon: starting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                          label: Text(l10n.welcomeStart),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        TextButton(
                          onPressed: starting
                              ? null
                              : () => context.push(AppRoutes.auth),
                          child: Text(l10n.welcomeHaveAccount),
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

    // Sans barre d'app, l'écran choisit lui-même les icônes de la barre
    // d'état (edge-to-edge), comme le ferait celle du thème.
    final overlay = theme.appBarTheme.systemOverlayStyle;
    return overlay == null
        ? screen
        : AnnotatedRegion<SystemUiOverlayStyle>(value: overlay, child: screen);
  }

  /// Ouvre AnKi en invité ; l'accès accordé, le routeur montre l'accueil.
  Future<void> _start(WidgetRef ref) async {
    final started = await ref
        .read(authControllerProvider.notifier)
        .signInAnonymously();
    if (started) unawaited(HapticFeedback.lightImpact());
  }
}

/// Ciel du soir (clair) ou de nuit (sombre) où veille la lune : le héros
/// (signature S1) et la mascotte (S2) de la bienvenue.
class _NightHero extends StatelessWidget {
  const _NightHero({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.ankiColors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        gradient: colors.hero,
        shadows: colors.floatingShadow,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
        ),
      ),
      child: SizedBox(
        height: height,
        child: Center(
          child: ExcludeSemantics(
            child: SizedBox.square(
              dimension: height * 0.75,
              child: Image.asset(AppAssets.moon),
            ),
          ),
        ),
      ),
    );
  }
}
