import 'dart:async';
import 'dart:typed_data';

import 'package:an_ki/core/common/anki_text_field.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
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

class BirthdayFormSheet extends ConsumerStatefulWidget {
  final Birthday? birthdayToEdit;

  const BirthdayFormSheet({super.key, this.birthdayToEdit});

  static Future<bool?> show(BuildContext context, {Birthday? birthdayToEdit}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.birthdayToEdit != null
                              ? context.l10n.editBirthday
                              : context.l10n.newBirthday,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Center(
                      child: _ImagePickerButton(
                        picture: _picture ?? widget.birthdayToEdit?.picture,
                        onTap: _pickImage,
                      ),
                    ),
                    const SizedBox(height: 32),

                    AnKiTextField(
                      controller: _nameController,
                      label: context.l10n.firstName,
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (v) => BirthdayDraft.isValidName(v ?? '')
                          ? null
                          : context.l10n.requiredField,
                    ),
                    const SizedBox(height: 16),
                    AnKiTextField(
                      controller: _surnameController,
                      label: context.l10n.lastName,
                      prefixIcon: Icons.badge_outlined,
                      validator: (v) => BirthdayDraft.isValidName(v ?? '')
                          ? null
                          : context.l10n.requiredField,
                    ),
                    const SizedBox(height: 24),

                    Text(
                      context.l10n.category,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 24),

                    _DatePickerField(
                      label: context.l10n.birthDate,
                      date: _selectedDate,
                      onTap: () => _showDatePicker(context),
                    ),

                    const SizedBox(height: 40),
                    Row(
                      children: [
                        if (widget.birthdayToEdit != null) ...[
                          IconButton.filledTonal(
                            onPressed: _delete,
                            style: IconButton.styleFrom(
                              foregroundColor: colorScheme.error,
                              backgroundColor: colorScheme.errorContainer
                                  .withValues(alpha: 0.3),
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _save,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: Icon(
                              widget.birthdayToEdit != null
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                            ),
                            label: Text(
                              widget.birthdayToEdit != null
                                  ? context.l10n.save
                                  : context.l10n.add,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = ref.read(clockProvider)();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Container(
        height: 350,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.birthDate,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.add),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                maximumDate: now,
                onDateTimeChanged: (date) =>
                    setState(() => _selectedDate = date),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePickerButton extends StatelessWidget {
  const _ImagePickerButton({this.picture, required this.onTap});

  final Uint8List? picture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final picture = this.picture;
    final ImageProvider? image = picture != null ? MemoryImage(picture) : null;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: colorScheme.surfaceContainerHigh,
            backgroundImage: image,
            child: image == null
                ? Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: 18,
                color: colorScheme.onPrimary,
              ),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = selectedIds.contains(cat.id);
          final colorScheme = Theme.of(context).colorScheme;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat.localizedName(context)),
              avatar: Icon(
                cat.iconData,
                size: 18,
                color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(cat.id),
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.edit_calendar_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
