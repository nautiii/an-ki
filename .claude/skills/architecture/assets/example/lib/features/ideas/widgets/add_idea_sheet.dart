import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/ideas/domain/idea.dart';
import 'package:an_ki/features/ideas/providers/idea_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Feuille de saisie rapide d'une idée.
///
/// Valide avec la règle du domaine ([IdeaDraft.isValid]), lance l'écriture
/// sans l'attendre puis se ferme : l'échec éventuel est signalé par l'écran
/// hôte, qui écoute [ideaEditorProvider].
class AddIdeaSheet extends ConsumerStatefulWidget {
  const AddIdeaSheet({super.key, this.personId});

  final String? personId;

  static Future<void> show(BuildContext context, {String? personId}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => AddIdeaSheet(personId: personId),
      );

  @override
  ConsumerState<AddIdeaSheet> createState() => _AddIdeaSheetState();
}

class _AddIdeaSheetState extends ConsumerState<AddIdeaSheet> {
  final _title = TextEditingController();

  IdeaDraft get _draft =>
      IdeaDraft(title: _title.text, personId: widget.personId);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_draft.isValid) return;
    unawaited(ref.read(ideaEditorProvider.notifier).add(_draft));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: IdeaDraft.maxTitleLength,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: context.l10n.ideaTitleLabel),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _draft.isValid ? _submit : null,
            child: Text(context.l10n.add),
          ),
        ],
      ),
    );
  }
}
