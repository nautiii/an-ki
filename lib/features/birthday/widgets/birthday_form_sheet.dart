import 'dart:convert';
import 'dart:io';

import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/category_model.dart';
import 'package:an_ki/data/models/create_birthday_input.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class BirthdayFormSheet extends ConsumerStatefulWidget {
  final BirthdayModel? birthdayToEdit;

  const BirthdayFormSheet({super.key, this.birthdayToEdit});

  static Future<bool?> show(
    BuildContext context, {
    BirthdayModel? birthdayToEdit,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
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
  DateTime _selectedDate = DateTime.now().subtract(
    const Duration(days: 365 * 25),
  );
  XFile? _selectedImage;

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
    if (image != null) setState(() => _selectedImage = image);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authState = ref.read(authProvider);
    final uid = authState.user?.uid;
    if (uid == null) return;

    final input = CreateBirthdayInput(
      uid: uid,
      name: _nameController.text.trim(),
      surname: _surnameController.text.trim(),
      date: _selectedDate,
      categories: _selectedCategories,
      pictureFile: _selectedImage,
    );

    try {
      if (widget.birthdayToEdit != null) {
        await ref
            .read(birthdayProvider.notifier)
            .updateBirthday(uid, widget.birthdayToEdit!.id, input);
      } else {
        await ref.read(birthdayProvider.notifier).createBirthday(uid, input);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorSavingBirthday)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCreating = ref.watch(birthdayProvider.select((s) => s.isCreating));
    final categories = ref.watch(categoriesProvider);

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
                        imageFile: _selectedImage,
                        initialImageUrl: widget.birthdayToEdit?.picture,
                        onTap: _pickImage,
                      ),
                    ),
                    const SizedBox(height: 32),

                    _ModernTextField(
                      controller: _nameController,
                      label: context.l10n.firstName,
                      icon: Icons.person_outline_rounded,
                      validator:
                          (v) =>
                              v?.isEmpty ?? true
                                  ? context.l10n.requiredField
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    _ModernTextField(
                      controller: _surnameController,
                      label: context.l10n.lastName,
                      icon: Icons.badge_outlined,
                      validator:
                          (v) =>
                              v?.isEmpty ?? true
                                  ? context.l10n.requiredField
                                  : null,
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
                    categories.when(
                      data:
                          (categories) => _CategorySelector(
                            categories: categories,
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
                      loading: () => const LinearProgressIndicator(),
                      error: (e, s) => const SizedBox(),
                    ),
                    const SizedBox(height: 24),

                    _DatePickerField(
                      label: context.l10n.birthDate,
                      date: _selectedDate,
                      onTap: () => _showDatePicker(context),
                    ),

                    const SizedBox(height: 40),
                    FilledButton.icon(
                      onPressed: isCreating ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon:
                          isCreating
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Icon(
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
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (_) => Container(
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
                    maximumDate: DateTime.now(),
                    onDateTimeChanged:
                        (date) => setState(() => _selectedDate = date),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _ImagePickerButton extends StatelessWidget {
  const _ImagePickerButton({
    this.imageFile,
    this.initialImageUrl,
    required this.onTap,
  });

  final XFile? imageFile;
  final String? initialImageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    ImageProvider? image;
    if (imageFile != null) {
      image = FileImage(File(imageFile!.path));
    } else if (initialImageUrl != null) {
      try {
        image = MemoryImage(base64Decode(initialImageUrl!));
      } catch (_) {}
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: colorScheme.surfaceContainerHigh,
            backgroundImage: image,
            child:
                image == null
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

class _ModernTextField extends StatelessWidget {
  const _ModernTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
        children:
            categories.map((cat) {
              final isSelected = selectedIds.contains(cat.id);
              final colorScheme = Theme.of(context).colorScheme;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat.getLocalizedName(context)),
                  avatar: Icon(
                    cat.iconData,
                    size: 18,
                    color:
                        isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.primary,
                  ),
                  selected: isSelected,
                  onSelected: (_) => onChanged(cat.id),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
