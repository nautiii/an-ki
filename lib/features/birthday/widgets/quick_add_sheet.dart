import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birth_date_input.dart';
import 'package:an_ki/features/birthday/domain/quick_birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birth_date_field.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/group_picker.dart';
import 'package:an_ki/features/birthday/widgets/quick_add_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Ajout en une ligne : « Léa 12 mars » et Entrée. Sous le champ, ce
/// qu'AnKi a compris (le nom, la date, l'âge si l'année est connue) ou ce
/// qui manque ; plusieurs lignes collées s'ajoutent d'un coup.
///
/// Remplace le formulaire à l'ajout une fois celui-ci appris
/// (`showAddBirthday`) ; « Formulaire complet » y revient avec ce qui a été
/// compris. Les groupes et la photo restent facultatifs, sous la saisie.
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key, this.initialText});

  /// Début de la ligne (le texte d'une recherche sans résultat) : la saisie
  /// reprend derrière.
  final String? initialText;

  static Future<bool?> show(BuildContext context, {String? initialText}) {
    return showModalBottomSheet<bool>(
      context: context,
      // Au-dessus de la barre flottante, pas dans l'onglet.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => QuickAddSheet(initialText: initialText),
    );
  }

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  static const _gutter = EdgeInsets.symmetric(horizontal: AppSpacing.lg);

  late final TextEditingController _text;
  final _focus = FocusNode();
  final _categories = <String>[];

  /// Photo choisie, lue dès le choix ; une seule personne à la fois.
  Uint8List? _picture;

  /// Entrée a été tapée sur une ligne incomplète : ce qui manque se dit en
  /// erreur, plus seulement en aide.
  bool _submitted = false;

  /// Personne que « Ajouter et continuer » vient d'ajouter, rappelée sous le
  /// champ vidé.
  String? _added;

  @override
  void initState() {
    super.initState();
    final start = widget.initialText?.trim() ?? '';
    _text = TextEditingController(text: start.isEmpty ? '' : '$start ');
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String _) => setState(() {
    _submitted = false;
    _added = null;
  });

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (mounted) setState(() => _picture = bytes);
  }

  void _toggleCategory(String id) => setState(() {
    if (!_categories.remove(id)) _categories.add(id);
  });

  List<QuickBirthday> _read() => readQuickBirthdays(
    _text.text,
    ref.read(todayProvider),
    order: typedDateOrder(context),
  );

  /// Entrée : ajoute ce qui est prêt, sinon dit ce qui manque.
  void _submit() {
    final lines = _read();
    if (lines.length > 1) {
      _addBatch();
    } else if (lines.firstOrNull?.isReady ?? false) {
      _add(keepOpen: false);
    } else {
      setState(() => _submitted = true);
    }
  }

  /// Ajoute la personne de la ligne ; la feuille se ferme, ou se vide pour
  /// la suivante ([keepOpen]). Un échec est annoncé par l'accueil.
  void _add({required bool keepOpen}) {
    final lines = _read();
    final draft = lines.length == 1
        ? lines.single.draft(categories: [..._categories], picture: _picture)
        : null;
    if (draft == null) return;
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      ref
          .read(birthdayEditorProvider.notifier)
          .create(draft, announced: keepOpen),
    );
    if (!keepOpen) {
      Navigator.of(context).pop(true);
      return;
    }
    final message = context.l10n.birthdayAdded(draft.fullName);
    _text.clear();
    setState(() {
      _categories.clear();
      _picture = null;
      _submitted = false;
      _added = draft.fullName;
    });
    _focus.requestFocus();
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
  }

  /// Ajoute les personnes nouvelles d'une liste collée.
  void _addBatch() {
    final batch = previewQuickBatch(
      _read(),
      existing: ref.read(birthdaysListProvider),
    );
    if (batch.fresh.isEmpty) return;
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      ref.read(birthdayEditorProvider.notifier).createAll([
        for (final line in batch.fresh) line.draft(categories: _categories)!,
      ]),
    );
    Navigator.of(context).pop(true);
  }

  /// Le formulaire classique, avec le nom et la date déjà compris.
  void _openForm() {
    final lines = _read();
    final line = lines.length == 1 ? lines.single : null;
    final navigator = Navigator.of(context);
    navigator.pop();
    unawaited(
      BirthdayFormSheet.show(
        navigator.context,
        initialName: line?.fullName,
        initialDate: switch (line?.date) {
          BirthDateComplete(:final date) => date,
          _ => null,
        },
        initialCategories: [..._categories],
        initialPicture: _picture,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final today = ref.watch(todayProvider);
    final existing = ref.watch(birthdaysListProvider);
    final lines = readQuickBirthdays(
      _text.text,
      today,
      order: typedDateOrder(context),
    );
    final batch = lines.length > 1
        ? previewQuickBatch(lines, existing: existing)
        : null;
    final line = lines.firstOrNull;
    final (helper, error) = batch != null || (line?.isReady ?? false)
        ? (null, null)
        : _feedback(context, line, submitted: _submitted, added: _added);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: _gutter,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Header(),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _text,
                          focusNode: _focus,
                          autofocus: true,
                          minLines: 1,
                          maxLines: 4,
                          // Une ligne au clavier, Entrée ajoute ; une liste
                          // collée garde ses retours à la ligne.
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          textCapitalization: TextCapitalization.words,
                          onChanged: _changed,
                          onSubmitted: (_) => _submit(),
                          // Garde le clavier ouvert quand Entrée ne suffit pas.
                          onEditingComplete: () {},
                          decoration: InputDecoration(
                            labelText: l10n.quickAddLabel,
                            helperText: helper,
                            helperMaxLines: 4,
                            errorText: error,
                            errorMaxLines: 3,
                          ),
                        ),
                        if (batch != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          QuickBatchPreview(batch: batch),
                        ] else if (line != null && line.isReady) ...[
                          const SizedBox(height: AppSpacing.sm),
                          QuickLinePreview(
                            line: line,
                            today: today,
                            known: isKnownBirthday(line, existing),
                            picture: _picture,
                            onPickPhoto: _pickImage,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.quickAddGroups,
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ),
                  ),
                  GroupPicker(
                    selectedIds: _categories,
                    onToggle: _toggleCategory,
                    padding: _gutter,
                  ),
                  if (batch == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: _openForm,
                          icon: const Icon(Icons.edit_note_rounded),
                          label: Text(l10n.quickAddFullForm),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Les boutons restent au-dessus du clavier, sous le pouce.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: _Actions(
              batch: batch,
              ready: line?.isReady ?? false,
              onAdd: () => _add(keepOpen: false),
              onContinue: () => _add(keepOpen: true),
              onAddAll: _addBatch,
            ),
          ),
        ],
      ),
    );
  }
}

/// Titre et fermeture.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.newBirthday,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton.filledTonal(
          onPressed: () => Navigator.pop(context),
          tooltip: l10n.close,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

/// Les boutons sous le pouce : « Ajouter » et « Ajouter et continuer » pour
/// une ligne, « Ajouter les N » pour une liste collée ([batch]).
class _Actions extends StatelessWidget {
  const _Actions({
    required this.batch,
    required this.ready,
    required this.onAdd,
    required this.onContinue,
    required this.onAddAll,
  });

  final QuickBatch? batch;

  /// La ligne peut devenir un anniversaire.
  final bool ready;
  final VoidCallback onAdd;
  final VoidCallback onContinue;
  final VoidCallback onAddAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final batch = this.batch;
    return OverflowBar(
      alignment: MainAxisAlignment.end,
      overflowAlignment: OverflowBarAlignment.end,
      spacing: AppSpacing.xs,
      overflowSpacing: AppSpacing.xs,
      children: batch != null
          ? [
              FilledButton.icon(
                onPressed: batch.fresh.isEmpty ? null : onAddAll,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.quickAddAll(batch.fresh.length)),
              ),
            ]
          : [
              TextButton(
                onPressed: ready ? onContinue : null,
                child: Text(l10n.quickAddContinue),
              ),
              FilledButton.icon(
                onPressed: ready ? onAdd : null,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.add),
              ),
            ],
    );
  }
}

/// Aide et erreur sous le champ pour une ligne qui n'est pas prête : une
/// date impossible se dit tout de suite ; ce qui manque, en aide pendant la
/// frappe, en erreur après Entrée ([submitted]).
(String?, String?) _feedback(
  BuildContext context,
  QuickBirthday? line, {
  required bool submitted,
  required String? added,
}) {
  final l10n = context.l10n;
  (String?, String?) missing(String message) =>
      submitted ? (null, message) : (message, null);
  final named = line != null && line.fullName.isNotEmpty;
  return switch (line?.date) {
    null => (
      added != null ? l10n.birthdayAdded(added) : l10n.quickAddHelper,
      null,
    ),
    BirthDateInvalid(error: BirthDateError.noSuchDate) => (
      null,
      l10n.birthDateInvalid,
    ),
    BirthDateInvalid(error: BirthDateError.future) => (
      null,
      l10n.birthDateFuture,
    ),
    BirthDateInvalid(error: BirthDateError.incompleteYear) => missing(
      l10n.birthYearDigits,
    ),
    BirthDateIncomplete() => missing(l10n.birthDateIncomplete),
    BirthDateEmpty() => missing(
      named ? l10n.quickAddNeedsDate : l10n.quickAddNeedsName,
    ),
    BirthDateComplete() => missing(l10n.quickAddNeedsName),
  };
}
