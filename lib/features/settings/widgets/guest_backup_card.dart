import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/auth/widgets/auth_failure_text.dart';
import 'package:an_ki/features/birthday/domain/guest_merge_plan.dart';
import 'package:an_ki/features/settings/domain/guest_merge_failure.dart';
import 'package:an_ki/features/settings/providers/guest_merge.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Carte « Gardez vos N anniversaires » d'un invité, en fin d'agenda (`app/router`
/// la confie à l'accueil) : la sauvegarde proposée au moment où l'agenda a de
/// la valeur, jamais comme un mur. « Sauvegarder avec Google » lie le compte
/// invité à Google, même compte et mêmes données ; réussie, la carte
/// disparaît avec l'invité et un message le confirme.
///
/// Compte Google déjà connu d'AnKi : la carte propose de l'ouvrir avec les
/// anniversaires de l'invité ([GuestMerge]), ou d'en choisir un autre. Adresse
/// déjà celle d'un compte e-mail : seulement un autre compte. Un autre échec
/// s'affiche sous le texte ; une annulation ne change rien.
class GuestBackupCard extends ConsumerStatefulWidget {
  const GuestBackupCard({super.key, required this.count});

  /// Anniversaires de l'invité, que la carte annonce.
  final int count;

  @override
  ConsumerState<GuestBackupCard> createState() => _GuestBackupCardState();
}

class _GuestBackupCardState extends ConsumerState<GuestBackupCard> {
  /// Refus de la dernière liaison pour un compte déjà pris :
  /// [AuthFailure.credentialAlreadyInUse] ou [AuthFailure.emailAlreadyInUse] ;
  /// null tant qu'aucun compte n'a été refusé.
  AuthFailure? _taken;

  /// Échec de la dernière tentative lancée d'ici ([AuthFailure] ou
  /// [GuestMergeFailure]) ; null au repos.
  Object? _failure;

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
    // Chaque essai oublie le compte Google choisi avant : sauf un nouveau
    // refus « déjà pris », plus rien n'est à ouvrir. Annulé (sélecteur
    // fermé), l'essai ne laisse pas d'échec.
    final error = ref.read(authControllerProvider).error;
    setState(() {
      if (error == AuthFailure.credentialAlreadyInUse ||
          error == AuthFailure.emailAlreadyInUse) {
        _taken = error as AuthFailure;
        _failure = null;
      } else {
        _taken = null;
        _failure = switch (error) {
          null => null,
          final AuthFailure failure => failure,
          _ => AuthFailure.unknown,
        };
      }
    });
  }

  Future<void> _open() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final plan = await ref.read(guestMergeProvider.notifier).merge();
    if (plan != null) {
      unawaited(HapticFeedback.lightImpact());
      messenger.showSnackBar(SnackBar(content: Text(_mergeDone(l10n, plan))));
      return;
    }
    if (!mounted) {
      // La carte part avec l'invité, à la connexion : sans plan, la reprise
      // qui suivait a échoué.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.guestMergeIncomplete)),
      );
      return;
    }
    final error = ref.read(guestMergeProvider).error;
    if (error == null) return;
    if (error == GuestMergeFailure.incomplete) {
      // Le compte est ouvert : l'invité n'est plus, la carte va partir.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.guestMergeIncomplete)),
      );
      return;
    }
    setState(() => _failure = error);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final tones = context.ankiColors.moonlight;
    final onCard = tones.onContainer;
    final busy =
        ref.watch(authControllerProvider.select((state) => state.isLoading)) ||
        ref.watch(guestMergeProvider.select((state) => state.isLoading));
    final taken = _taken != null;
    final canOpen = _taken == AuthFailure.credentialAlreadyInUse;
    final failure = _failure;
    final accent = FilledButton.styleFrom(
      backgroundColor: tones.color,
      foregroundColor: tones.onColor,
    );

    return Card(
      color: tones.container,
      // Titre, message et boutons restent des nœuds distincts pour TalkBack.
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
                canOpen
                    ? l10n.guestBackupMergeMessage(widget.count)
                    : taken
                    ? l10n.guestBackupTakenMessage(widget.count)
                    : l10n.guestBackupMessage(widget.count),
                style: theme.textTheme.bodyMedium?.copyWith(color: onCard),
              ),
            ),
            if (failure != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _FailureLine(message: _failureText(context, failure)),
            ],
            const SizedBox(height: AppSpacing.sm),
            if (canOpen) ...[
              // Pleine largeur : le libellé, long, passe à la ligne à 200 %.
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : _open,
                  style: accent,
                  icon: busy ? const _Progress() : null,
                  label: Text(l10n.guestBackupMergeAction(widget.count)),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: busy ? null : _save,
                style: TextButton.styleFrom(foregroundColor: onCard),
                child: Text(l10n.guestBackupOtherAccount),
              ),
            ] else
              FilledButton.icon(
                onPressed: busy ? null : _save,
                // Plein, dans l'accent de la carte : une pilule tonale s'y
                // confondait (contraste 1:1 avec le fond moonlight).
                style: accent,
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

/// « 9 anniversaires ajoutés à ce compte · 3 y étaient déjà ».
String _mergeDone(AppLocalizations l10n, GuestMergePlan plan) =>
    l10n.guestMergeDone(plan.moves.length, plan.duplicates.length);

/// Ce qui s'est passé et quoi faire, selon l'échec.
String _failureText(BuildContext context, Object failure) => switch (failure) {
  final AuthFailure failure => failure.message(context),
  GuestMergeFailure.offline => context.l10n.guestMergeOffline,
  GuestMergeFailure.failed => context.l10n.guestMergeFailed,
  GuestMergeFailure.incomplete => context.l10n.guestMergeIncomplete,
  _ => AuthFailure.unknown.message(context),
};

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
