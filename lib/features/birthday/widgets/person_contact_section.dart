import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/contact_link.dart';
import 'package:an_ki/features/birthday/domain/contact_link_failure.dart';
import 'package:an_ki/features/birthday/providers/contact_links.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Le contact d'une personne sur sa page (P5), sur opt-in : rien n'est relié
/// tant que l'utilisateur ne choisit pas un numéro dans le sélecteur du
/// système, et ce numéro reste sur ce téléphone.
///
/// - Non reliée : « Relier à un contact », avec ce qu'AnKi reçoit et où il le
///   garde, avant que le sélecteur ne s'ouvre.
/// - Reliée : le contact et son numéro, « Message » et « Appeler » ; le menu
///   change de contact ou délie (avec « Annuler »).
///
/// Rien hors Android, où le sélecteur et les intents n'existent pas.
class PersonContactSection extends ConsumerWidget {
  const PersonContactSection({super.key, required this.birthday});

  final Birthday birthday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(contactLinkSupportedProvider)) {
      return const SizedBox.shrink();
    }
    ref.listen(contactLinkerProvider, (_, next) {
      if (next case AsyncError(error: final ContactLinkFailure failure)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(contactLinkFailureText(context.l10n, failure)),
            ),
          );
      }
    });
    // Rien tant que le stockage n'a pas répondu : « Relier » ne doit pas
    // s'offrir, un instant, à une personne déjà reliée.
    if (!ref.watch(contactLinksProvider.select((links) => links.hasValue))) {
      return const SizedBox.shrink();
    }
    final link = ref.watch(contactLinkProvider(birthday.id));
    final picking = ref.watch(
      contactLinkerProvider.select((state) => state.isLoading),
    );

    // L'écart qui suit vit ici : sans section, pas d'espace vide.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: link == null
          ? _LinkTile(birthdayId: birthday.id, picking: picking)
          : _LinkedCard(birthdayId: birthday.id, link: link, picking: picking),
    );
  }
}

/// Texte d'un échec de la liaison.
String contactLinkFailureText(
  AppLocalizations l10n,
  ContactLinkFailure failure,
) => switch (failure) {
  ContactLinkFailure.pickerUnavailable => l10n.contactLinkPickerUnavailable,
  ContactLinkFailure.storageFailed => l10n.contactLinkStorageFailed,
  ContactLinkFailure.appUnavailable => l10n.contactAppUnavailable,
};

const _shape = RoundedSuperellipseBorder(
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
);

/// « Relier à un contact » : la promesse dite avant le sélecteur.
class _LinkTile extends ConsumerWidget {
  const _LinkTile({required this.birthdayId, required this.picking});

  final String birthdayId;
  final bool picking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      shape: _shape,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        // Le lotus : le lien aux gens.
        leading: Icon(Icons.person_add_alt_1_rounded, color: scheme.secondary),
        title: Text(l10n.contactLinkAction),
        subtitle: Text(l10n.contactLinkPrivacy),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: scheme.onSurfaceVariant,
        ),
        enabled: !picking,
        onTap: () => unawaited(
          ref.read(contactLinkerProvider.notifier).pick(birthdayId),
        ),
      ),
    );
  }
}

/// Le contact relié : qui, quel numéro, et les deux gestes.
class _LinkedCard extends ConsumerWidget {
  const _LinkedCard({
    required this.birthdayId,
    required this.link,
    required this.picking,
  });

  final String birthdayId;
  final ContactLink link;
  final bool picking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final linker = ref.read(contactLinkerProvider.notifier);
    final named = link.contactName.isNotEmpty;

    return Material(
      color: scheme.surfaceContainerLow,
      shape: _shape,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xxs,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.contact_phone_rounded,
                    color: scheme.secondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  // Lu d'un trait : « Léa Martin, 06 12 34 56 78, Relié sur
                  // ce téléphone ».
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          named ? link.contactName : link.number,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (named)
                          Text(
                            link.number,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        Text(
                          l10n.contactLinkOnThisPhone,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _LinkMenu(birthdayId: birthdayId, enabled: !picking),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => unawaited(linker.message(link.number, '')),
                    icon: const Icon(Icons.sms_rounded),
                    label: Text(l10n.contactMessage),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(linker.dial(link.number)),
                    icon: const Icon(Icons.call_rounded),
                    label: Text(l10n.contactCall),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _LinkAction { change, remove }

/// « Changer de contact » et « Délier », rares : dans un menu.
class _LinkMenu extends ConsumerWidget {
  const _LinkMenu({required this.birthdayId, required this.enabled});

  final String birthdayId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<_LinkAction>(
      tooltip: l10n.contactLinkMenu,
      enabled: enabled,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) => switch (action) {
        _LinkAction.change => unawaited(
          ref.read(contactLinkerProvider.notifier).pick(birthdayId),
        ),
        _LinkAction.remove => unawaited(_unlink(context, ref)),
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _LinkAction.change,
          child: Text(l10n.contactLinkChange),
        ),
        PopupMenuItem(
          value: _LinkAction.remove,
          child: Text(l10n.contactLinkRemove),
        ),
      ],
    );
  }

  /// Délie tout de suite, « Annuler » rétablit : pas de confirmation pour un
  /// geste qui se défait.
  ///
  /// Tout passe par le conteneur, pas par la page : la snackbar survit à la
  /// page quittée, et « Annuler » doit encore trouver un contrôleur en vie.
  Future<void> _unlink(BuildContext context, WidgetRef ref) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final removed = await _withLinker(
      container,
      (linker) => linker.unlink(birthdayId),
    );
    if (removed == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.contactLinkRemoved),
          // Depuis Flutter 3.44, une snackbar avec action reste sinon ouverte.
          persist: false,
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => unawaited(
              _withLinker(
                container,
                (linker) => linker.restore(birthdayId, removed),
              ),
            ),
          ),
        ),
      );
  }

  /// Lance [action] sur le contrôleur, gardé en vie jusqu'à sa fin même si
  /// la page qui l'écoutait a disparu.
  static Future<T> _withLinker<T>(
    ProviderContainer container,
    Future<T> Function(ContactLinker linker) action,
  ) {
    final keepAlive = container.listen(contactLinkerProvider, (_, _) {});
    return action(container.read(contactLinkerProvider.notifier))
        .whenComplete(keepAlive.close);
  }
}
