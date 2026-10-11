import 'dart:async';
import 'dart:typed_data';

import 'package:an_ki/core/common/anki_text_field.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_draft.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class BirthdayFormSheet extends ConsumerStatefulWidget {
  final Birthday? birthdayToEdit;

  const BirthdayFormSheet({super.key, this.birthdayToEdit});

  static Future<bool?> show(BuildContext context, {Birthday? birthdayToEdit}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => BirthdayFormSheet(birthdayToEdit: birthdayToEdit),
    );
  }

  @override
  ConsumerState<BirthdayFormSheet> createState() => _BirthdayFormSheetState();
}

class _BirthdayFormSheetState extends ConsumerState<BirthdayFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _surnameController;

  List<String> _selectedCategories = [];
  late DateTime _selectedDate = ref
      .read(clockProvider)()
      .subtract(const Duration(days: 365 * 25));

  /// Photo choisie dans la galerie, lue dès le choix : le brouillon porte des
  /// octets, jamais un fichier.
  Uint8List? _picture;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.birthdayToEdit?.name);
    _surnameController = TextEditingController(
      text: widget.birthdayToEdit?.surname,
    );

    if (widget.birthdayToEdit != null) {
      _selectedDate = widget.birthdayToEdit!.date;
      _selectedCategories = List.from(widget.birthdayToEdit!.categories);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    super.dispose();
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

  /// Valide, lance l'écriture sans l'attendre puis ferme la feuille : un échec
  /// éventuel est annoncé par l'écran d'accueil.
  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final draft = BirthdayDraft(
      name: _nameController.text.trim(),
      surname: _surnameController.text.trim(),
      date: _selectedDate,
      categories: _selectedCategories,
      picture: _picture,
    );

    final editor = ref.read(birthdayEditorProvider.notifier);
    final toEdit = widget.birthdayToEdit;
    unawaited(
      toEdit != null ? editor.edit(toEdit.id, draft) : editor.create(draft),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteBirthdayTitle),
        content: Text(
          context.l10n.deleteBirthdayConfirmation(
            "${widget.birthdayToEdit!.name} ${widget.birthdayToEdit!.surname}",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      unawaited(
        ref
            .read(birthdayEditorProvider.notifier)
            .delete(widget.birthdayToEdit!.id),
      );
      Navigator.of(context).pop(true);
    }
  }

  void _showDatePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => _DateSheet(
        initialDate: _selectedDate,
        maximumDate: ref.read(clockProvider)(),
        onChanged: (date) => setState(() => _selectedDate = date),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isEditing = widget.birthdayToEdit != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing
                          ? context.l10n.editBirthday
                          : context.l10n.newBirthday,
                      style: textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    tooltip: context.l10n.close,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: _ImagePickerButton(
                  picture: _picture ?? widget.birthdayToEdit?.picture,
                  onTap: _pickImage,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AnKiTextField(
                controller: _nameController,
                label: context.l10n.firstName,
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) => BirthdayDraft.isValidName(v ?? '')
                    ? null
                    : context.l10n.requiredField,
              ),
              const SizedBox(height: AppSpacing.md),
              AnKiTextField(
                controller: _surnameController,
                label: context.l10n.lastName,
                prefixIcon: Icons.badge_outlined,
                validator: (v) => BirthdayDraft.isValidName(v ?? '')
                    ? null
                    : context.l10n.requiredField,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                context.l10n.category,
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _CategorySelector(
                categories: ref.watch(userCategoriesProvider),
                selectedIds: _selectedCategories,
                onChanged: (id) {
                  setState(() {
                    if (_selectedCategories.contains(id)) {
                      _selectedCategories.remove(id);
                    } else {
                      _selectedCategories.add(id);
                    }
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              _DatePickerField(
                label: context.l10n.birthDate,
                date: _selectedDate,
                onTap: () => _showDatePicker(context),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  if (isEditing) ...[
                    IconButton.filledTonal(
                      onPressed: _delete,
                      tooltip: context.l10n.delete,
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
                      onPressed: _save,
                      icon: Icon(
                        isEditing ? Icons.check_rounded : Icons.add_rounded,
                      ),
                      label: Text(
                        isEditing ? context.l10n.save : context.l10n.add,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Choix de la photo : avatar touchable, annoncé comme un bouton.
class _ImagePickerButton extends StatelessWidget {
  const _ImagePickerButton({this.picture, required this.onTap});

  final Uint8List? picture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final picture = this.picture;
    final ImageProvider? image = picture != null ? MemoryImage(picture) : null;

    return Semantics(
      button: true,
      label: context.l10n.choosePhoto,
      excludeSemantics: true,
      onTap: onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundImage: image,
            child: Icon(
              Icons.person_rounded,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
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
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: 18,
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

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.categories,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<BirthdayCategory> categories;
  final List<String> selectedIds;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final category in categories)
          ChoiceChip(
            avatar: Icon(category.iconData),
            label: Text(category.localizedName(context)),
            selected: selectedIds.contains(category.id),
            onSelected: (_) => onChanged(category.id),
          ),
      ],
    );
  }
}

/// Champ de date : ouvre le sélecteur, affiche la date dans la langue de l'app.
class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          color: colorScheme.surfaceContainerHigh,
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          DateFormat.yMMMMd(locale).format(date),
                          style: textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.edit_calendar_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Feuille du sélecteur de date : la roue suit la date, « Valider » ferme.
class _DateSheet extends StatelessWidget {
  const _DateSheet({
    required this.initialDate,
    required this.maximumDate,
    required this.onChanged,
  });

  final DateTime initialDate;
  final DateTime maximumDate;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.birthDate,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.confirm),
              ),
            ],
          ),
          const Divider(),
          SizedBox(
            height: 216,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: initialDate,
              maximumDate: maximumDate,
              onDateTimeChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
