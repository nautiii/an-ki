import 'dart:async';

import 'package:an_ki/core/common/anki_text_field.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/providers/category_editor.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      // Au-dessus de la barre flottante, pas dans l'onglet.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
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

  /// Lance les écritures sans les attendre puis ferme la feuille : un échec
  /// éventuel est annoncé par l'écran d'accueil.
  void _save() {
    final customName = _controller.text.trim();

    if (customName.isEmpty && _selectedDefaultIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.selectOrCreateCategory)),
      );
      return;
    }

    final editor = ref.read(categoryEditorProvider.notifier);
    // Catégories suggérées sélectionnées.
    if (_selectedDefaultIds.isNotEmpty) {
      unawaited(editor.addToProfile(_selectedDefaultIds.toList()));
    }
    // Catégorie personnalisée.
    if (customName.isNotEmpty) {
      unawaited(editor.create(customName, _selectedIconCode));
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sectionStyle = textTheme.labelLarge?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final categoriesState = ref.watch(categoriesProvider);
    final user = ref.watch(userProfileProvider).value;
    final userCategoryIds = user?.categories ?? [];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xl,
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
                      context.l10n.newCategory,
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

              // Section Catégories par défaut
              Text(context.l10n.suggestedCategories, style: sectionStyle),
              const SizedBox(height: AppSpacing.sm),
              categoriesState.when(
                data: (allCategories) {
                  final availableDefaults = allCategories
                      .where((cat) => !userCategoryIds.contains(cat.id))
                      .toList();

                  if (availableDefaults.isEmpty) {
                    return Text(context.l10n.noMoreSuggestions);
                  }

                  return Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final category in availableDefaults)
                        FilterChip(
                          avatar: Icon(category.iconData),
                          label: Text(category.localizedName(context)),
                          selected: _selectedDefaultIds.contains(category.id),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedDefaultIds.add(category.id);
                              } else {
                                _selectedDefaultIds.remove(category.id);
                              }
                            });
                          },
                        ),
                    ],
                  );
                },
                loading: () => const Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    SkeletonBox(height: 32, width: 96, radius: AppRadii.md),
                    SkeletonBox(height: 32, width: 112, radius: AppRadii.md),
                    SkeletonBox(height: 32, width: 88, radius: AppRadii.md),
                  ],
                ),
                error: (_, _) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),

              // Section Catégorie personnalisée
              Text(context.l10n.createCustomCategory, style: sectionStyle),
              const SizedBox(height: AppSpacing.md),
              AnKiTextField(
                controller: _controller,
                label: context.l10n.categoryName,
                // Dynamic icon: code is user-selected at runtime, not const.
                prefixIcon: IconData(
                  // ignore: non_const_argument_for_const_parameter
                  _selectedIconCode,
                  fontFamily: 'MaterialIcons',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(context.l10n.chooseIcon, style: sectionStyle),
              const SizedBox(height: AppSpacing.md),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: AppSpacing.xs,
                  crossAxisSpacing: AppSpacing.xs,
                ),
                itemCount: _availableIcons.length,
                itemBuilder: (context, index) {
                  final icon = _availableIcons[index];
                  return _IconOption(
                    icon: icon,
                    label: context.l10n.iconOption(index + 1),
                    isSelected: _selectedIconCode == icon.codePoint,
                    onTap: () =>
                        setState(() => _selectedIconCode = icon.codePoint),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.add_rounded),
                label: Text(context.l10n.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une icône de la grille : un bouton sélectionnable, nommé pour TalkBack.
class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: isSelected
            ? colorScheme.primary
            : colorScheme.surfaceContainerHigh,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
