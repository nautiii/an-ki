import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CategoryFormSheet(),
    );
  }

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _selectedIconCode = Icons.category_rounded.codePoint;
  final Set<String> _selectedDefaultIds = {};

  final List<IconData> _availableIcons = [
    Icons.category_rounded,
    Icons.group_rounded,
    Icons.work_rounded,
    Icons.favorite_rounded,
    Icons.school_rounded,
    Icons.celebration_rounded,
    Icons.share_rounded,
    Icons.sports_martial_arts_rounded,
    Icons.restaurant_rounded,
    Icons.sports_esports_rounded,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final customName = _controller.text.trim();

    if (customName.isEmpty && _selectedDefaultIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.selectOrCreateCategory)),
      );
      return;
    }

    // Si on a des catégories par défaut sélectionnées
    if (_selectedDefaultIds.isNotEmpty) {
      await ref
          .read(categoryNotifierProvider.notifier)
          .addCategoriesToUser(_selectedDefaultIds.toList());
    }

    // Si on a un nom personnalisé, on crée la catégorie
    if (customName.isNotEmpty) {
      await ref
          .read(categoryNotifierProvider.notifier)
          .createAndAddCategory(customName, _selectedIconCode);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final categoriesState = ref.watch(categoriesProvider);
    final user = ref.watch(userProvider).user;
    final userCategoryIds = user?.categories ?? [];

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
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.l10n.newCategory,
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

                    // Section Catégories par défaut
                    Text(
                      context.l10n.suggestedCategories,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    categoriesState.when(
                      data: (allCategories) {
                        final availableDefaults =
                            allCategories
                                .where(
                                  (cat) => !userCategoryIds.contains(cat.id),
                                )
                                .toList();

                        if (availableDefaults.isEmpty) {
                          return Text(context.l10n.noMoreSuggestions);
                        }

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children:
                                availableDefaults.map((cat) {
                                  final isSelected = _selectedDefaultIds
                                      .contains(cat.id);
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(
                                        cat.getLocalizedName(context),
                                      ),
                                      avatar: Icon(
                                        cat.iconData,
                                        size: 18,
                                        color:
                                            isSelected
                                                ? colorScheme.onPrimary
                                                : colorScheme.primary,
                                      ),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedDefaultIds.add(cat.id);
                                          } else {
                                            _selectedDefaultIds.remove(cat.id);
                                          }
                                        });
                                      },
                                      showCheckmark: false,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        );
                      },
                      loading:
                          () =>
                              const Center(child: CircularProgressIndicator()),
                      error: (_, _) => const SizedBox(),
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),

                    // Section Catégorie personnalisée
                    Text(
                      context.l10n.createCustomCategory,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controller,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: context.l10n.categoryName,
                        prefixIcon: Icon(
                          IconData(
                            _selectedIconCode,
                            fontFamily: 'MaterialIcons',
                          ),
                          color: colorScheme.primary,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      context.l10n.chooseIcon,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: _availableIcons.length,
                      itemBuilder: (context, index) {
                        final icon = _availableIcons[index];
                        final isSelected = _selectedIconCode == icon.codePoint;
                        return InkWell(
                          onTap:
                              () => setState(
                                () => _selectedIconCode = icon.codePoint,
                              ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              color:
                                  isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        context.l10n.add,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
