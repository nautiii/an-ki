import 'dart:async';

import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/anki_colors.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday_dates.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/domain/contact_import_failure.dart';
import 'package:an_ki/features/birthday/domain/contact_import_preview.dart';
import 'package:an_ki/features/birthday/providers/contact_import.dart';
import 'package:an_ki/features/birthday/widgets/birthday_display.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Import des anniversaires du répertoire : l'accès se demande à l'arrivée,
/// puis l'utilisateur choisit qui ajouter — cochés d'avance, du plus proche
/// anniversaire au plus lointain, ceux qu'AnKi connaît déjà à part. Ouvert
/// depuis l'accueil vide et les réglages ; « Ajouter » ferme l'écran, et
/// l'app annonce l'ajout sur l'écran d'origine (`birthdayAdditionsProvider`).
class ContactImportScreen extends ConsumerStatefulWidget {
  const ContactImportScreen({super.key});

  @override
  ConsumerState<ContactImportScreen> createState() =>
      _ContactImportScreenState();
}

class _ContactImportScreenState extends ConsumerState<ContactImportScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Retour des réglages : l'accès a pu être accordé entre-temps.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (ref.read(contactImportProvider).hasError) {
          unawaited(ref.read(contactImportProvider.notifier).reloadIfAllowed());
        }
      },
    );
    // L'utilisateur vient de choisir ses contacts : l'accès se demande tout
    // de suite, la boîte système par-dessus le chargement.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(contactImportProvider.notifier).load());
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Ajoute les contacts cochés, puis revient à l'écran d'origine. L'app
  /// annonce l'ajout : un message, ou la proposition des rappels qui le dit.
  void _add() {
    final added = ref
        .read(contactImportProvider.notifier)
        .add(ref.read(contactImportTickedProvider));
    if (added == 0) return;
    unawaited(HapticFeedback.lightImpact());
    context.pop();
  }

  /// Ferme l'import pour la saisie à la main, par-dessus l'écran d'origine.
  void _addByHand() {
    final navigator = Navigator.of(context);
    context.pop();
    unawaited(BirthdayFormSheet.show(navigator.context));
  }

  @override
  Widget build(BuildContext context) {
    final import = ref.watch(contactImportPreviewProvider);
    final controller = ref.read(contactImportProvider.notifier);
    final l10n = context.l10n;

    final Widget body = switch (import) {
      AsyncValue(hasError: true, :final error) => switch (error) {
        ContactImportFailure.permissionDenied => _NoAccess(
          message: l10n.contactImportDeniedMessage,
          actionLabel: l10n.contactImportAllow,
          onAction: () => unawaited(controller.load()),
          onAddByHand: _addByHand,
        ),
        ContactImportFailure.permissionBlocked => _NoAccess(
          message: l10n.contactImportBlockedMessage,
          actionLabel: l10n.openAppSettings,
          onAction: () => unawaited(controller.openAppSettings()),
          onAddByHand: _addByHand,
        ),
        _ => _Centered(
          child: AnKiEmptyState(
            illustration: const _StateIcon(Icons.sync_problem_rounded),
            title: l10n.contactImportErrorTitle,
            message: l10n.contactImportErrorMessage,
            primaryLabel: l10n.retry,
            onPrimary: () => unawaited(controller.load()),
          ),
        ),
      },
      AsyncData(value: final preview?)
          when preview.fresh.isEmpty && preview.known.isEmpty =>
        _Centered(
          child: AnKiEmptyState(
            illustration: Image.asset(AppAssets.moon),
            title: l10n.contactImportEmptyTitle,
            message: l10n.contactImportEmptyMessage,
            primaryLabel: l10n.addByHand,
            onPrimary: _addByHand,
          ),
        ),
      AsyncData(value: final preview?) => _Preview(
        preview: preview,
        onAdd: _add,
      ),
      // Avant la première lecture, puis pendant l'accès et la lecture.
      _ => const _LoadingRows(),
    };

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(l10n.contactImportTitle),
      ),
      body: body,
    );
  }
}

/// L'aperçu : qui ajouter, puis qui AnKi connaît déjà, et l'action en bas.
class _Preview extends ConsumerWidget {
  const _Preview({required this.preview, required this.onAdd});

  final ContactImportPreview preview;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final excluded = ref.watch(contactImportExclusionsProvider);
    final ticked = ref.watch(contactImportTickedProvider).length;
    final exclusions = ref.read(contactImportExclusionsProvider.notifier);
    final fresh = preview.fresh;
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  AppSpacing.xs,
                ),
                child: Text(
                  fresh.isEmpty
                      ? l10n.contactImportAllKnown
                      : l10n.contactImportFound(fresh.length),
                  style: secondary,
                ),
              ),
              if (fresh.isNotEmpty) ...[
                // « Tout cocher » : une ligne comme les autres, à trois états.
                CheckboxListTile(
                  tristate: true,
                  value: ticked == fresh.length
                      ? true
                      : ticked == 0
                      ? false
                      : null,
                  onChanged: (_) {
                    HapticFeedback.selectionClick();
                    exclusions.toggleAll(fresh);
                  },
                  title: Text(
                    l10n.contactImportSelectAll(fresh.length),
                    style: theme.textTheme.titleSmall,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                  ),
                ),
                const Divider(
                  indent: AppSpacing.gutter,
                  endIndent: AppSpacing.gutter,
                ),
                for (final contact in fresh)
                  CheckboxListTile(
                    value: !excluded.contains(contact),
                    onChanged: (_) {
                      HapticFeedback.selectionClick();
                      exclusions.toggle(contact);
                    },
                    secondary: AnKiAvatar(name: contact.fullName),
                    title: Text(contact.fullName),
                    subtitle: Text(_detail(context, contact, today)),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                    ),
                  ),
              ],
              if (preview.known.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.lg,
                    AppSpacing.gutter,
                    AppSpacing.xxs,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.contactImportKnown,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                for (final contact in preview.known)
                  _KnownTile(
                    contact: contact,
                    detail: _detail(context, contact, today),
                  ),
              ],
            ],
          ),
        ),
        // Tous déjà dans AnKi : rien à ajouter, la croix suffit.
        if (fresh.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xs,
                AppSpacing.gutter,
                AppSpacing.md,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: ticked == 0 ? null : onAdd,
                  child: Text(l10n.contactImportAdd(ticked)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// « 21 octobre · dans 3 jours » : la date, et sa proximité pour choisir.
  static String _detail(
    BuildContext context,
    BirthdayDraft contact,
    DateTime today,
  ) => context.l10n.contactImportDetail(
    contact.date.formatted(context, includeYear: false),
    contact.date.daysUntilNext(today),
  );
}

/// Personne déjà dans AnKi : lisible, sans case à cocher (rien à importer).
class _KnownTile extends StatelessWidget {
  const _KnownTile({required this.contact, required this.detail});

  final BirthdayDraft contact;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: AnKiAvatar(name: contact.fullName),
      title: Text(contact.fullName),
      subtitle: Text(detail),
      trailing: ExcludeSemantics(
        child: Icon(
          Icons.check_circle_rounded,
          color: context.ankiColors.success.color,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
    );
  }
}

/// Accès refusé : ce qu'il faut faire, et une issue sans les contacts.
class _NoAccess extends StatelessWidget {
  const _NoAccess({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onAddByHand,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onAddByHand;

  @override
  Widget build(BuildContext context) {
    return _Centered(
      child: AnKiEmptyState(
        illustration: const _StateIcon(Icons.contacts_outlined),
        title: context.l10n.contactImportDeniedTitle,
        message: message,
        primaryLabel: actionLabel,
        onPrimary: onAction,
        secondaryLabel: context.l10n.addByHand,
        onSecondary: onAddByHand,
      ),
    );
  }
}

/// Icône d'un état, sur un disque au ton de la lune.
class _StateIcon extends StatelessWidget {
  const _StateIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tones = context.ankiColors.moonlight;
    return Center(
      child: CircleAvatar(
        radius: 40,
        backgroundColor: tones.container,
        child: Icon(icon, size: 32, color: tones.onContainer),
      ),
    );
  }
}

/// Centré dans la page, et défile en grand texte plutôt que de déborder.
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - 2 * AppSpacing.lg,
          ),
          child: Center(child: SafeArea(top: false, child: child)),
        ),
      ),
    );
  }
}

/// Lignes squelettes, à la forme des contacts à venir.
class _LoadingRows extends StatelessWidget {
  const _LoadingRows();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.xs,
      ),
      children: [
        for (var i = 0; i < 6; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                SkeletonBox(height: 48, width: 48, radius: 24),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 16, width: 160),
                      SizedBox(height: AppSpacing.xs),
                      SkeletonBox(height: 12, width: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
