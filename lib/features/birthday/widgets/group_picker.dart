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

/// Groupes de la personne sur une ligne qui défile, ceux proposés à tous
/// d'abord ; « Nouveau groupe » au bout ouvre la création juste dessous, sans
/// quitter la saisie ni empiler une feuille.
class GroupPicker extends ConsumerStatefulWidget {
  const GroupPicker({
    super.key,
    required this.selectedIds,
    required this.onToggle,
    required this.padding,
  });

  final List<String> selectedIds;

  /// Coche ou décoche un groupe ; un groupe créé ici arrive coché.
  final ValueChanged<String> onToggle;
  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<GroupPicker> createState() => _GroupPickerState();
}

class _GroupPickerState extends ConsumerState<GroupPicker> {
  bool _creating = false;

  void _created(String id) {
    setState(() => _creating = false);
    widget.onToggle(id);
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(userCategoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: widget.padding,
          child: Row(
            spacing: AppSpacing.xs,
            children: [
              for (final group in groups)
                _GroupChip(
                  group: group,
                  selected: widget.selectedIds.contains(group.id),
                  onToggle: () => widget.onToggle(group.id),
                ),
              ActionChip(
                avatar: Icon(
                  _creating ? Icons.close_rounded : Icons.add_rounded,
                ),
                label: Text(context.l10n.newGroup),
                onPressed: () => setState(() => _creating = !_creating),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: context.motion(AppMotion.enter),
          curve: AppMotion.enterCurve,
          alignment: Alignment.topCenter,
          child: _creating
              ? Padding(
                  padding: widget.padding.add(
                    const EdgeInsets.only(top: AppSpacing.sm),
                  ),
                  child: _NewGroup(
                    groups: groups,
                    onCreated: _created,
                    onCancel: () => setState(() => _creating = false),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Un groupe à cocher : son icône à sa teinte, remplacée par la coche une
/// fois choisi.
class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.group,
    required this.selected,
    required this.onToggle,
  });

  final BirthdayCategory group;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: selected
          ? null
          : Icon(group.iconData, color: group.tones(context).color),
      label: Text(group.localizedName(context)),
      selected: selected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        onToggle();
      },
    );
  }
}

/// Création d'un groupe : son nom, sa teinte (la première libre, déjà
/// choisie), « Créer » tant que le nom est neuf.
class _NewGroup extends ConsumerStatefulWidget {
  const _NewGroup({
    required this.groups,
    required this.onCreated,
    required this.onCancel,
  });

  /// Groupes existants : leurs noms sont pris, leurs teintes déjà portées.
  final List<BirthdayCategory> groups;
  final ValueChanged<String> onCreated;
  final VoidCallback onCancel;

  @override
  ConsumerState<_NewGroup> createState() => _NewGroupState();
}

class _NewGroupState extends ConsumerState<_NewGroup> {
  final _name = TextEditingController();
  final _focus = FocusNode();
  late int _tone = firstFreeTone(
    widget.groups.map((group) => group.toneIndex),
    LabelTones.pickable,
  );

  @override
  void initState() {
    super.initState();
    // La saisie passe au nom du groupe, même si le nom de la personne
    // l'avait : `autofocus` ne prend pas un focus déjà donné.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  GroupNameIssue? _issue(BuildContext context) => groupNameIssue(_name.text, [
    for (final group in widget.groups) group.localizedName(context),
  ]);

  /// Écriture optimiste : le groupe apparaît coché aussitôt, un échec est
  /// annoncé par l'accueil.
  void _create() {
    if (_issue(context) != null) return;
    final id = ref
        .read(categoryEditorProvider.notifier)
        .create(_name.text, icon: Icons.label_rounded.codePoint, tone: _tone);
    if (id == null) return;
    unawaited(HapticFeedback.lightImpact());
    widget.onCreated(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final issue = _issue(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          focusNode: _focus,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _create(),
          decoration: InputDecoration(
            labelText: l10n.groupName,
            hintText: l10n.groupNameHint,
            errorText: issue == GroupNameIssue.taken
                ? l10n.groupNameTaken
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TonePicker(
          selected: _tone,
          onSelected: (tone) => setState(() => _tone = tone),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.xs,
          children: [
            TextButton(onPressed: widget.onCancel, child: Text(l10n.cancel)),
            FilledButton.tonal(
              onPressed: issue == null ? _create : null,
              child: Text(l10n.createGroup),
            ),
          ],
        ),
      ],
    );
  }
}
