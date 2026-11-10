import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_search.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:an_ki/features/books/providers/shelf_providers.dart';
import 'package:an_ki/features/books/widgets/series_cover.dart';
import 'package:an_ki/features/books/widgets/shelf_undo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _SeriesAction { rename, merge, toggleComplete, delete }

/// Menu de la page d'une série : renommer, fusionner avec une autre,
/// marquer terminée (ou en cours), supprimer. Ce qui se défait a
/// « Annuler » ; un renommage se refait simplement.
class SeriesMenu extends ConsumerWidget {
  const SeriesMenu({super.key, required this.entry});

  final ShelfEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canMerge = ref.watch(
      shelfProvider.select((shelf) => (shelf.value?.entries.length ?? 0) > 1),
    );
    return PopupMenuButton<_SeriesAction>(
      tooltip: l10n.seriesMenu,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) => switch (action) {
        _SeriesAction.rename => unawaited(_rename(context, ref)),
        _SeriesAction.merge => unawaited(_merge(context)),
        _SeriesAction.toggleComplete => _toggleComplete(context, ref),
        _SeriesAction.delete => deleteSeriesWithUndo(context, entry),
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _SeriesAction.rename,
          child: _MenuRow(Icons.edit_rounded, l10n.seriesRename),
        ),
        PopupMenuItem(
          value: _SeriesAction.merge,
          enabled: canMerge,
          child: _MenuRow(Icons.merge_rounded, l10n.seriesMerge),
        ),
        PopupMenuItem(
          value: _SeriesAction.toggleComplete,
          child: entry.series.complete
              ? _MenuRow(Icons.replay_rounded, l10n.seriesMarkOngoing)
              : _MenuRow(
                  Icons.check_circle_outline_rounded,
                  l10n.seriesMarkComplete,
                ),
        ),
        PopupMenuItem(
          value: _SeriesAction.delete,
          child: _MenuRow(Icons.delete_outline_rounded, l10n.seriesDelete),
        ),
      ],
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    // Lu avant l'attente : le menu peut ne plus exister à la fermeture.
    final container = ProviderScope.containerOf(context, listen: false);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: entry.series.name),
    );
    if (name == null || name.trim() == entry.series.name) return;
    unawaited(
      container
          .read(shelfEditorProvider.notifier)
          .renameSeries(entry.series.id, name),
    );
  }

  Future<void> _merge(BuildContext context) async {
    final target = await showModalBottomSheet<ShelfEntry>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _MergeSheet(source: entry),
    );
    if (target == null || !context.mounted) return;
    mergeSeriesWithUndo(context, source: entry, target: target);
  }

  /// Marque la série terminée (ou en cours) tout de suite ; « Annuler »
  /// remet l'état d'avant.
  void _toggleComplete(BuildContext context, WidgetRef ref) {
    final container = ProviderScope.containerOf(context, listen: false);
    final uid = container.read(currentUidProvider);
    final series = entry.series;
    final complete = !series.complete;
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      container
          .read(shelfEditorProvider.notifier)
          .setComplete(series.id, complete: complete),
    );
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            complete
                ? l10n.seriesMarkedComplete(series.name)
                : l10n.seriesMarkedOngoing(series.name),
          ),
          persist: false,
          duration: MediaQuery.accessibleNavigationOf(context)
              ? shelfUndoDelay * 2
              : shelfUndoDelay,
          action: SnackBarAction(
            label: l10n.undo,
            // L'éditeur est relu : la page a pu se fermer entre-temps.
            onPressed: () => unawaited(
              container
                  .read(shelfEditorProvider.notifier)
                  .setComplete(series.id, complete: series.complete, uid: uid),
            ),
          ),
        ),
      );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon),
      const SizedBox(width: AppSpacing.sm),
      Flexible(child: Text(label)),
    ],
  );
}

/// Dialogue « Renommer la série » : le nom actuel prérempli, un nom vide
/// refusé.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  /// Le champ a été touché : son erreur peut s'afficher.
  bool _touched = false;

  bool get _empty => _controller.text.trim().isEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_empty) return;
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.seriesRenameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() => _touched = true),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: l10n.seriesNameLabel,
          errorText: _touched && _empty ? l10n.seriesNameRequired : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _empty ? null : _submit,
          child: Text(l10n.seriesRename),
        ),
      ],
    );
  }
}

/// Feuille « Fusionner … avec » : les autres séries, de A à Z ; renvoie
/// celle qui reçoit les tomes.
class _MergeSheet extends ConsumerWidget {
  const _MergeSheet({required this.source});

  final ShelfEntry source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final others = searchShelf(
      ref.watch(shelfProvider).value?.entries ?? const [],
      '',
    ).where((entry) => entry.series.id != source.series.id).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.seriesMergeTitle(source.series.name),
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.seriesMergeHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              children: [
                for (final entry in others)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    leading: SeriesCover(
                      name: entry.series.name,
                      imageUrl: entry.coverUrl,
                      width: 32,
                    ),
                    title: Text(entry.series.name),
                    onTap: () => Navigator.pop(context, entry),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
