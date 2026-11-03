import 'dart:async';

import 'package:an_ki/core/common/anki_avatar.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birth_date_input.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/widgets/birth_date_field.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:an_ki/features/birthday/widgets/group_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Feuille d'ajout ou de modification d'un anniversaire, faite pour la saisie
/// express : un seul champ « Prénom et nom », la date tapée au clavier
/// (l'année est facultative), les groupes sur une ligne.
///
/// Une création tient en « + », le nom, « Suivant », quatre chiffres, « OK ».
class BirthdayFormSheet extends ConsumerStatefulWidget {
  final Birthday? birthdayToEdit;

  /// Nom pré-rempli d'une création (le texte d'une recherche sans résultat) :
  /// la saisie reprend alors à la date.
  final String? initialName;

  const BirthdayFormSheet({super.key, this.birthdayToEdit, this.initialName});

  static Future<bool?> show(
    BuildContext context, {
    Birthday? birthdayToEdit,
    String? initialName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      // Au-dessus de la barre flottante, pas dans l'onglet.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => BirthdayFormSheet(
        birthdayToEdit: birthdayToEdit,
        initialName: initialName,
      ),
    );
  }

  @override
  ConsumerState<BirthdayFormSheet> createState() => _BirthdayFormSheetState();
}

class _BirthdayFormSheetState extends ConsumerState<BirthdayFormSheet> {
  static const _gutter = EdgeInsets.symmetric(horizontal: AppSpacing.lg);

  late final TextEditingController _name;
  late final TextEditingController _date;
  final _dateFocus = FocusNode();
  late final List<String> _categories;

  /// Champ qui ouvre le clavier à la création : le nom, ou la date quand le
  /// nom vient d'une recherche. La modification ne l'ouvre pas.
  late final bool _autofocusName;
  late final bool _autofocusDate;

  /// Vrai dès que le nom a été modifié : un nom vide n'est signalé qu'ensuite.
  bool _nameEdited = false;

  /// Photo choisie dans la galerie, lue dès le choix : le brouillon porte des
  /// octets, jamais un fichier.
  Uint8List? _picture;

  @override
  void initState() {
    super.initState();
    final birthday = widget.birthdayToEdit;
    _name = TextEditingController(
      text: birthday?.fullName ?? widget.initialName?.trim(),
    );
    // Pré-remplie dans didChangeDependencies : son texte suit la région.
    _date = TextEditingController();
    _categories = [...?birthday?.categories];
    _autofocusName = birthday == null && _name.text.isEmpty;
    _autofocusDate = birthday == null && _name.text.isNotEmpty;
    // Quitter le champ de date peut changer son aide en erreur.
    _dateFocus.addListener(_refresh);
  }

  /// La date à modifier est écrite dans le champ, une fois.
  bool _datePrefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_datePrefilled) return;
    _datePrefilled = true;
    if (widget.birthdayToEdit case final birthday?) {
      _date.text = birthDateInputText(
        birthday.date,
        order: typedDateOrder(context),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _date.dispose();
    _dateFocus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

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

  /// Lance l'écriture sans l'attendre puis ferme la feuille : un échec
  /// éventuel est annoncé par l'écran d'accueil.
  void _save() {
    final date = parseBirthDate(
      _date.text,
      ref.read(todayProvider),
      order: typedDateOrder(context),
    );
    if (!BirthdayDraft.isValidName(_name.text) || date is! BirthDateComplete) {
      return;
    }
    final (:name, :surname) = BirthdayDraft.splitFullName(_name.text);
    final draft = BirthdayDraft(
      name: name,
      surname: surname,
      date: date.date,
      categories: _categories,
      picture: _picture,
    );

    final editor = ref.read(birthdayEditorProvider.notifier);
    final toEdit = widget.birthdayToEdit;
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      toEdit != null ? editor.edit(toEdit.id, draft) : editor.create(draft),
    );
    Navigator.of(context).pop(true);
  }

  /// Supprime avec « Annuler » : la feuille se ferme, la snackbar de
  /// l'accueil laisse quelques secondes pour revenir en arrière.
  void _delete() {
    deleteWithUndo(context, widget.birthdayToEdit!);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final isEditing = widget.birthdayToEdit != null;
    final order = typedDateOrder(context);
    final date = parseBirthDate(_date.text, today, order: order);
    final nameIsValid = BirthdayDraft.isValidName(_name.text);
    final canSave = nameIsValid && date is BirthDateComplete;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: _gutter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEditing ? l10n.editBirthday : l10n.newBirthday,
                          style: textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton.filledTonal(
                        onPressed: () => Navigator.pop(context),
                        tooltip: l10n.close,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      _PhotoButton(
                        name: _name.text,
                        picture: _picture ?? widget.birthdayToEdit?.picture,
                        onTap: _pickImage,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _name,
                          autofocus: _autofocusName,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() => _nameEdited = true),
                          // « Suivant » passe à la date, clavier ouvert.
                          onEditingComplete: _dateFocus.requestFocus,
                          decoration: InputDecoration(
                            labelText: l10n.fullName,
                            hintText: l10n.fullNameHint,
                            errorText: _nameEdited && !nameIsValid
                                ? l10n.requiredField
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BirthDateField(
                    controller: _date,
                    focusNode: _dateFocus,
                    input: date,
                    order: order,
                    today: today,
                    autofocus: _autofocusDate,
                    onChanged: (_) => setState(() {}),
                    // « OK » enregistre ; sinon le champ quitté dit ce qui
                    // manque.
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.groups,
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
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: _gutter,
              child: Row(
                children: [
                  if (isEditing) ...[
                    IconButton.filledTonal(
                      onPressed: _delete,
                      tooltip: l10n.delete,
                      style: IconButton.styleFrom(
                        foregroundColor: colorScheme.onErrorContainer,
                        backgroundColor: colorScheme.errorContainer,
                        minimumSize: const Size.square(56),
                        shape: const RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(AppRadii.md),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canSave ? _save : null,
                      icon: Icon(
                        isEditing ? Icons.check_rounded : Icons.add_rounded,
                      ),
                      label: Text(isEditing ? l10n.save : l10n.add),
                    ),
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

/// Avatar de la personne, ses initiales suivant la saisie ; le toucher
/// choisit une photo.
class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.name,
    required this.picture,
    required this.onTap,
  });

  final String name;
  final Uint8List? picture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final picture = this.picture;

    return Semantics(
      button: true,
      label: context.l10n.choosePhoto,
      excludeSemantics: true,
      onTap: onTap,
      child: Stack(
        children: [
          AnKiAvatar(
            name: name,
            image: picture != null ? MemoryImage(picture) : null,
            radius: 28,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.surfaceContainerLow,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: 14,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          // Au-dessus de l'avatar, pour que l'onde du toucher reste visible.
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap),
            ),
          ),
        ],
      ),
    );
  }
}
