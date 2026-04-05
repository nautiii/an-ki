import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/create_birthday_input.dart';
import 'package:an_ki/providers/birthday_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CreateBirthdayPage extends StatefulWidget {
  const CreateBirthdayPage({super.key});

  @override
  State<CreateBirthdayPage> createState() => _CreateBirthdayPageState();
}

class _CreateBirthdayPageState extends State<CreateBirthdayPage> {
  static const Color _pageColor = Color(0xFF0B1C2C);
  static const Color _cardColor = Color(0xFF16263E);
  static const Color _accentColor = Color(0xFFD9A08B);
  static const Color _mutedTextColor = Color(0xFF98A6BD);
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _surnameController = TextEditingController();
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

    final CreateBirthdayInput input = CreateBirthdayInput(
      name: _nameController.text,
      surname: _surnameController.text,
      date: _selectedDate,
      category: _selectedCategory,
    );

    try {
      await context.read<BirthdayProvider>().createBirthday(input);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'enregistrer l'anniversaire."),
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    DateTime temporaryDate = _selectedDate;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cardColor,
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
                        child: const Text('Annuler'),
                      ),
                      const Text(
                        'Date de naissance',
                        style: TextStyle(
                          color: Colors.white,
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
                        child: const Text('Valider'),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
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
    const List<String> months = <String>[
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Champ requis';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isCreating = context.select<BirthdayProvider, bool>(
      (BirthdayProvider provider) => provider.isCreating,
    );

    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        backgroundColor: _pageColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: isCreating ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(
          'Nouvel anniversaire',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: isCreating ? null : _save,
            child:
                isCreating
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text(
                      'Enregistrer',
                      style: TextStyle(
                        color: _accentColor,
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
                const _AvatarSection(),
                const SizedBox(height: 28),
                _InputCard(
                  label: 'Prénom',
                  controller: _nameController,
                  validator: _requiredValidator,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.givenName],
                ),
                const SizedBox(height: 16),
                _InputCard(
                  label: 'Nom',
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
                  label: 'Date de naissance',
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
  const _AvatarSection();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Align(
            alignment: Alignment.center,
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, size: 44, color: Colors.white),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 18,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: _CreateBirthdayPageState._accentColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                color: _CreateBirthdayPageState._pageColor,
              ),
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: _CreateBirthdayPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: _CreateBirthdayPageState._mutedTextColor,
            fontSize: 18,
          ),
          border: InputBorder.none,
          errorStyle: const TextStyle(color: Colors.redAccent),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: _CreateBirthdayPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Catégorie',
            style: TextStyle(
              color: _CreateBirthdayPageState._mutedTextColor,
              fontSize: 18,
            ),
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
    final Color backgroundColor =
        isSelected
            ? _CreateBirthdayPageState._accentColor
            : const Color(0xFF0F1B2D);
    final Color foregroundColor =
        isSelected ? _CreateBirthdayPageState._pageColor : Colors.white;

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
              category.label,
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
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: _CreateBirthdayPageState._cardColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _CreateBirthdayPageState._mutedTextColor,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: _CreateBirthdayPageState._accentColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white70,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension on BirthdayCategory {
  String get label {
    switch (this) {
      case BirthdayCategory.family:
        return 'Famille';
      case BirthdayCategory.friend:
        return 'Amis';
      case BirthdayCategory.colleague:
        return 'Collègues';
      case BirthdayCategory.other:
        return 'Autre';
    }
  }

  IconData get icon {
    switch (this) {
      case BirthdayCategory.family:
        return Icons.group_outlined;
      case BirthdayCategory.friend:
        return Icons.people_outline_rounded;
      case BirthdayCategory.colleague:
        return Icons.work_outline_rounded;
      case BirthdayCategory.other:
        return Icons.category_outlined;
    }
  }
}
