import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/core/theme/label_tones.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_groups.dart';
import 'package:an_ki/features/birthday/providers/category_editor.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:an_ki/features/birthday/widgets/tone_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modification d'un groupe privé : son nom et sa teinte. « Enregistrer »
/// tant que le nom est libre et que quelque chose a changé.
class GroupEditSheet extends ConsumerStatefulWidget {
  const GroupEditSheet({super.key, required this.group});

  final BirthdayCategory group;

  static Future<void> show(BuildContext context, BirthdayCategory group) =>
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => GroupEditSheet(group: group),
      );

  @override
  ConsumerState<GroupEditSheet> createState() => _GroupEditSheetState();
}

class _GroupEditSheetState extends ConsumerState<GroupEditSheet> {
  late final _name = TextEditingController(text: widget.group.name);

  /// Teinte du groupe, ou la première proposée si la sienne ne l'est pas
  /// (groupe sans teinte choisie) : choisir en fixe une.
  late final int _initialTone =
      LabelTones.pickable.contains(widget.group.toneIndex)
      ? widget.group.toneIndex
      : LabelTones.pickable.first;
  late int _tone = _initialTone;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  GroupNameIssue? _issue(List<BirthdayCategory> groups) =>
      groupNameIssue(_name.text, [
        for (final group in groups)
          if (group.id != widget.group.id) group.localizedName(context),
      ]);

  bool get _changed =>
      _name.text.trim() != widget.group.name || _tone != _initialTone;

  void _save() {
    if (_issue(ref.read(userCategoriesProvider)) != null || !_changed) return;
    ref
        .read(categoryEditorProvider.notifier)
        .edit(
          BirthdayCategory(
            id: widget.group.id,
            name: _name.text,
            icon: widget.group.icon,
            tone: _tone,
          ),
        );
    unawaited(HapticFeedback.lightImpact());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final issue = _issue(ref.watch(userCategoriesProvider));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.editGroup, style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: l10n.groupName,
              errorText: issue == GroupNameIssue.taken
                  ? l10n.groupNameTaken
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TonePicker(
            selected: _tone,
            onSelected: (tone) => setState(() => _tone = tone),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: issue == null && _changed ? _save : null,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
