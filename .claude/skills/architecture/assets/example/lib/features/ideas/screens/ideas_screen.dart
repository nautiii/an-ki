import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/ideas/domain/idea.dart';
import 'package:an_ki/features/ideas/providers/idea_editor.dart';
import 'package:an_ki/features/ideas/providers/ideas_providers.dart';
import 'package:an_ki/features/ideas/widgets/add_idea_sheet.dart';
import 'package:an_ki/features/ideas/widgets/idea_failure_text.dart';
import 'package:an_ki/features/ideas/widgets/idea_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Liste des idées cadeaux : rend l'état des providers, délègue les actions.
class IdeasScreen extends ConsumerWidget {
  const IdeasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Écoute aussi les écritures lancées depuis la feuille d'ajout, déjà
    // fermée quand un échec arrive.
    ref.listen(ideaEditorProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ideaFailureText(context.l10n, error))),
        );
      }
    });
    final ideas = ref.watch(ideasProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.ideasTitle)),
      body: switch (ideas) {
        AsyncValue(hasError: true) => _LoadError(
          onRetry: () => ref.invalidate(ideasProvider),
        ),
        AsyncValue(:final value?) when value.isEmpty => Center(
          child: Text(context.l10n.ideasEmpty),
        ),
        AsyncValue(:final value?) => _IdeaList(
          ideas: value,
          onDelete: (idea) =>
              unawaited(ref.read(ideaEditorProvider.notifier).delete(idea.id)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton(
        tooltip: context.l10n.ideaAdd,
        onPressed: () => AddIdeaSheet.show(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _IdeaList extends StatelessWidget {
  const _IdeaList({required this.ideas, required this.onDelete});

  final List<Idea> ideas;
  final void Function(Idea idea) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: ideas.length,
      itemBuilder: (context, index) {
        final idea = ideas[index];
        return IdeaTile(idea: idea, onDelete: () => onDelete(idea));
      },
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.ideasLoadError),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    );
  }
}
