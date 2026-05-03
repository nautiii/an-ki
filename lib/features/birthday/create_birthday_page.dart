import 'dart:convert';
import 'dart:io';

import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/create_birthday_input.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class CreateBirthdayPage extends ConsumerStatefulWidget {
  final BirthdayModel? birthdayToEdit;

  const CreateBirthdayPage({super.key, this.birthdayToEdit});

  @override
  ConsumerState<CreateBirthdayPage> createState() => _CreateBirthdayPageState();
}

class _CreateBirthdayPageState extends ConsumerState<CreateBirthdayPage> {
  static const List<BirthdayCategory> _availableCategories = <BirthdayCategory>[
    BirthdayCategory.family,
    BirthdayCategory.friend,
    BirthdayCategory.colleague,
    BirthdayCategory.other,
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _surnameController;

  BirthdayCategory _selectedCategory = BirthdayCategory.friend;
  DateTime _selectedDate = DateTime(2000, 6, 5);
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _surnameController = TextEditingController();

    if (widget.birthdayToEdit != null) {
      _populateFields(widget.birthdayToEdit!);
    }
  }

  void _populateFields(BirthdayModel birthday) {
    _nameController.text = birthday.name;
    _surnameController.text = birthday.surname;
    _selectedDate = birthday.date;
    _selectedCategory = birthday.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final FormState? form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    final authState = ref.read(authProvider);
    final birthdayNotifier = ref.read(birthdayProvider.notifier);

    final CreateBirthdayInput input = CreateBirthdayInput(
      uid: authState.user?.uid ?? '',
      name: _nameController.text,
      surname: _surnameController.text,
      date: _selectedDate,
      category: _selectedCategory,
      pictureFile: _selectedImage,
    );

    try {
      final uid = authState.user!.uid;
      final navigator = Navigator.of(context);

      if (widget.birthdayToEdit != null) {
        await birthdayNotifier.updateBirthday(
          uid,
          widget.birthdayToEdit!.id,
          input,
        );
      } else {
        await birthdayNotifier.createBirthday(uid, input);
      }
      navigator.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorSavingBirthday)),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  Future<void> _pickDate() async {
    DateTime temporaryDate = _selectedDate;
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.l10n.cancel),
                      ),
                      Text(
                        context.l10n.birthDate,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDate = DateTime(
                              temporaryDate.year,
                              temporaryDate.month,
                              temporaryDate.day,
                            );
                          });
                          Navigator.of(context).pop();
                        },
                        child: Text(context.l10n.validate),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _selectedDate,
                    minimumYear: 1900,
                    maximumYear: DateTime.now().year,
                    maximumDate: DateTime.now(),
                    onDateTimeChanged: (DateTime value) {
                      temporaryDate = value;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      context.l10n.january,
      context.l10n.february,
      context.l10n.march,
      context.l10n.april,
      context.l10n.may,
      context.l10n.june,
      context.l10n.july,
      context.l10n.august,
      context.l10n.september,
      context.l10n.october,
      context.l10n.november,
      context.l10n.december,
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.requiredField;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final birthdayState = ref.watch(birthdayProvider);
    final bool isCreating = birthdayState.isCreating;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: isCreating ? null : () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          widget.birthdayToEdit != null
              ? context.l10n.editBirthday
              : context.l10n.newBirthday,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: isCreating ? null : _save,
            child:
                isCreating
                    ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                    : Text(
                      context.l10n.save,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _AvatarSection(
                  imageFile: _selectedImage,
                  initialImageUrl: widget.birthdayToEdit?.picture,
                  onPickImage: _pickImage,
                ),
                const SizedBox(height: 28),
                _InputCard(
                  label: context.l10n.firstName,
                  controller: _nameController,
                  validator: _requiredValidator,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.givenName],
                ),
                const SizedBox(height: 16),
                _InputCard(
                  label: context.l10n.lastName,
                  controller: _surnameController,
                  validator: _requiredValidator,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.familyName],
                ),
                const SizedBox(height: 16),
                _CategorySection(
                  categories: _availableCategories,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (BirthdayCategory category) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _DateCard(
                  label: context.l10n.birthDate,
                  value: _formatDate(_selectedDate),
                  onTap: _pickDate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.imageFile,
    required this.onPickImage,
    this.initialImageUrl,
  });

  final XFile? imageFile;
  final String? initialImageUrl;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    ImageProvider? backgroundImage;

    if (imageFile != null) {
      backgroundImage = FileImage(File(imageFile!.path));
    } else if (initialImageUrl != null) {
      try {
        backgroundImage = MemoryImage(base64Decode(initialImageUrl!));
      } catch (e) {
        // Fallback if base64 is invalid
        backgroundImage = null;
      }
    }

    return GestureDetector(
      onTap: onPickImage,
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.center,
              child: CircleAvatar(
                radius: 44,
                backgroundColor: colorScheme.surfaceContainerHighest,
                backgroundImage: backgroundImage,
                child:
                    backgroundImage == null
                        ? Icon(
                          Icons.person,
                          size: 44,
                          color: colorScheme.onSurfaceVariant,
                        )
                        : null,
              ),
            ),
            Positioned(
              right: 12,
              bottom: 18,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.label,
    required this.controller,
    required this.validator,
    required this.textInputAction,
    required this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 18,
          ),
          border: InputBorder.none,
          errorStyle: TextStyle(color: colorScheme.error),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final List<BirthdayCategory> categories;
  final BirthdayCategory selectedCategory;
  final ValueChanged<BirthdayCategory> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.category,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 18),
          ),
          const SizedBox(height: 16),
          Row(
            children:
                categories.map((BirthdayCategory category) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: category == categories.last ? 0 : 12,
                      ),
                      child: _CategoryCard(
                        category: category,
                        isSelected: category == selectedCategory,
                        onTap: () => onCategorySelected(category),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final BirthdayCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color backgroundColor =
        isSelected ? colorScheme.primary : colorScheme.surfaceContainerLow;
    final Color foregroundColor =
        isSelected ? colorScheme.onPrimary : colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        height: 120,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(category.icon, color: foregroundColor, size: 28),
            const SizedBox(height: 10),
            Text(
              category.label(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.calendar_month_outlined, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
