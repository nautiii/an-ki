import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/auth/widgets/auth_failure_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Carte « Gardez vos N anniversaires » d'un invité, en fin d'agenda : la
/// sauvegarde proposée au moment où l'agenda a de la valeur, jamais comme un
/// mur. « Sauvegarder avec Google » lie le compte invité à Google, même
/// compte et mêmes données ; réussie, la carte disparaît avec l'invité et un
/// message le confirme.
///
/// Compte Google déjà connu d'AnKi : rien ne change, la carte l'explique et
/// propose d'en choisir un autre. Un autre échec s'affiche sous le texte ; une
/// annulation ne change rien.
class GuestBackupCard extends ConsumerStatefulWidget {
  const GuestBackupCard({super.key, required this.count});

  /// Anniversaires de l'invité, que la carte annonce.
  final int count;

  @override
  ConsumerState<GuestBackupCard> createState() => _GuestBackupCardState();
}

class _GuestBackupCardState extends ConsumerState<GuestBackupCard> {
  /// Échec de la dernière tentative lancée d'ici ; null au repos.
  AuthFailure? _failure;

  Future<void> _save() async {
    // Réussie, la carte part avec l'invité : le message passe par la
    // coquille, qui reste.
    final messenger = ScaffoldMessenger.of(context);
    final done = context.l10n.guestBackupDone(widget.count);
    final linked = await ref
        .read(authControllerProvider.notifier)
        .linkWithGoogle();
    if (linked) {
      unawaited(HapticFeedback.lightImpact());
      messenger.showSnackBar(SnackBar(content: Text(done)));
      return;
    }
    if (!mounted) return;
    // Annulée (sélecteur fermé), la tentative ne change rien à la carte.
    final error = ref.read(authControllerProvider).error;
    if (error == null) return;
    setState(
      () => _failure = error is AuthFailure ? error : AuthFailure.unknown,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final tones = context.ankiColors.moonlight;
    final onCard = tones.onContainer;
    final busy = ref.watch(
      authControllerProvider.select((state) => state.isLoading),
    );
    final taken = _failure == AuthFailure.credentialAlreadyInUse;
    final failure = taken ? null : _failure;

    return Card(
      color: tones.container,
      // Titre, message et bouton restent des nœuds distincts pour TalkBack.
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    taken
                        ? Icons.switch_account_outlined
                        : Icons.cloud_done_outlined,
                    color: onCard,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      taken
                          ? l10n.guestBackupTakenTitle
                          : l10n.guestBackupTitle(widget.count),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onCard,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Annoncé quand il change : le compte déjà pris s'explique ici.
            Semantics(
              liveRegion: true,
              child: Text(
                taken
                    ? l10n.guestBackupTakenMessage(widget.count)
                    : l10n.guestBackupMessage(widget.count),
                style: theme.textTheme.bodyMedium?.copyWith(color: onCard),
              ),
            ),
            if (failure != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _FailureLine(message: failure.message(context)),
            ],
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonalIcon(
              onPressed: busy ? null : _save,
              // Le temps du sélecteur Google puis de la liaison.
              icon: busy ? const _Progress() : null,
              label: Text(
                taken ? l10n.guestBackupOtherAccount : l10n.guestBackupAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Échec de la sauvegarde, sous le texte : ce qui s'est passé et quoi faire.
class _FailureLine extends StatelessWidget {
  const _FailureLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(Icons.error_outline_rounded, size: 20, color: color),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

/// Indicateur dans le bouton pendant la sauvegarde.
class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
