import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/ideas/domain/idea.dart';
import 'package:flutter/material.dart';

/// Ligne d'une idée. Widget « bête » : données en paramètres, actions en
/// callbacks, aucun provider lu ici.
class IdeaTile extends StatelessWidget {
  const IdeaTile({super.key, required this.idea, required this.onDelete});

  final Idea idea;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final note = idea.note;
    return ListTile(
      title: Text(idea.title),
      subtitle: note == null ? null : Text(note),
      trailing: IconButton(
        tooltip: context.l10n.delete,
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: onDelete,
      ),
    );
  }
}
