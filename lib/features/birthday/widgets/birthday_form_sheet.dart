import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birth_date_input.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/widgets/birth_date_field.dart';
import 'package:an_ki/features/birthday/widgets/add_mode_switch.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:an_ki/features/birthday/widgets/birthday_photo_button.dart';
import 'package:an_ki/features/birthday/widgets/group_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Formulaire d'un anniversaire : un champ « Prénom et nom », la date tapée
/// au clavier (l'année est facultative), les groupes sur une ligne.
///
/// Il modifie, et il crée dans la feuille d'ajout (`AddBirthdaySheet`), où
/// il est le mode par défaut : [onSwitchMode] y passe à l'ajout en une
/// ligne avec ce qui est saisi.
class BirthdayFormSheet extends ConsumerStatefulWidget {
  final Birthday? birthdayToEdit;

  /// Nom pré-rempli d'une création (le texte d'une recherche sans résultat) :
  /// la saisie reprend alors à la date.
  final String? initialName;

  /// Date pré-remplie d'une création : celle que l'ajout en une ligne avait
  /// lue.
  final BirthDate? initialDate;

  /// La date d'une création telle que tapée dans ce formulaire avant un
  /// aller-retour par l'ajout en une ligne, même incomplète ; prime sur
  /// [initialDate].
  final String initialDateText;

  /// La ligne d'où vient cette création (`AddHandoff.lineText`) : rendue
  /// telle quelle si l'on y revient sans toucher au nom ni à la date.
  final String initialLineText;

  /// Prendre le focus à l'ouverture, même si un autre champ l'a encore
  /// (changement de mode : le clavier reste ouvert).
  final bool focusOnStart;

  /// Première saisie (nom, date, groupe, photo).
  final VoidCallback? onEdited;

  /// Groupes et photo d'une création, choisis dans l'autre mode.
  final List<String> initialCategories;
  final Uint8List? initialPicture;

  /// Passe à l'ajout en une ligne avec ce qui est saisi ; null hors de la
  /// feuille d'ajout (modification) : pas de choix de mode.
  final ValueChanged<AddHandoff>? onSwitchMode;

  const BirthdayFormSheet({
    super.key,
    this.birthdayToEdit,
    this.initialName,
    this.initialDate,
    this.initialDateText = '',
    this.initialLineText = '',
    this.initialCategories = const [],
    this.initialPicture,
    this.focusOnStart = false,
    this.onEdited,
    this.onSwitchMode,
  });

  static Future<bool?> show(
    BuildContext context, {
    Birthday? birthdayToEdit,
    String? initialName,
    BirthDate? initialDate,
    List<String> initialCategories = const [],
    Uint8List? initialPicture,
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
        initialDate: initialDate,
        initialCategories: initialCategories,
        initialPicture: initialPicture,
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
  final _nameFocus = FocusNode();
  final _dateFocus = FocusNode();

  /// Le nom ou la date ont été touchés : la ligne d'origine ne vaut plus.
  bool _typed = false;

  void _edited() {
    _typed = true;
    widget.onEdited?.call();
  }

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
    _categories = [...(birthday?.categories ?? widget.initialCategories)];
    _picture = widget.initialPicture;
    _autofocusName = birthday == null && _name.text.isEmpty;
    _autofocusDate = birthday == null && _name.text.isNotEmpty;
    // Quitter le champ de date peut changer son aide en erreur.
    _dateFocus.addListener(_refresh);
    if (widget.focusOnStart) {
      // L'autofocus cède à un champ encore focalisé (celui de l'autre mode,
      // qui s'efface) : le focus est demandé, au frame suivant.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        (_name.text.isEmpty ? _nameFocus : _dateFocus).requestFocus();
      });
    }
  }

  /// La date à modifier est écrite dans le champ, une fois.
  bool _datePrefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_datePrefilled) return;
    _datePrefilled = true;
    if (widget.initialDateText.isNotEmpty) {
      _date.text = widget.initialDateText;
    } else if (widget.birthdayToEdit?.date ?? widget.initialDate
        case final date?) {
      _date.text = birthDateInputText(date, order: typedDateOrder(context));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _date.dispose();
    _nameFocus.dispose();
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
    if (!mounted) return;
    widget.onEdited?.call();
    setState(() => _picture = bytes);
  }

  void _toggleCategory(String id) {
    widget.onEdited?.call();
    setState(() {
      if (!_categories.remove(id)) _categories.add(id);
    });
  }

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

  /// Ce qui est saisi, pour l'ajout en une ligne.
  AddHandoff _handoff() => AddHandoff(
    name: _name.text.trim(),
    dateText: _date.text.trim(),
    lineText: _typed ? '' : widget.initialLineText,
    categories: [..._categories],
    picture: _picture,
  );

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
                  if (widget.onSwitchMode case final onSwitch?
                      when !isEditing) ...[
                    const SizedBox(height: AppSpacing.md),
                    AddModeSwitch(
                      mode: AddMode.form,
                      onChanged: (_) => onSwitch(_handoff()),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      BirthdayPhotoButton(
                        name: _name.text,
                        picture: _picture ?? widget.birthdayToEdit?.picture,
                        onTap: _pickImage,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _name,
                          focusNode: _nameFocus,
                          autofocus: _autofocusName,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            _edited();
                            setState(() => _nameEdited = true);
                          },
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
                    onChanged: (_) {
                      _edited();
                      setState(() {});
                    },
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
