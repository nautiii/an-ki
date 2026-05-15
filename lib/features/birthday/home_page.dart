import 'package:an_ki/core/common/header.dart';
import 'package:an_ki/core/common/search_bar.dart';
import 'package:an_ki/core/extensions/birthday_extensions.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/category_model.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/category_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/next_birthday.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'contact_sections.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredBirthdays = ref.watch(filteredBirthdaysProvider);
    final isLoading = ref.watch(birthdayProvider.select((s) => s.isLoading));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Header(),
              const SizedBox(height: 24),
              const NextBirthdayCard(),
              const SizedBox(height: 20),
              SearchBarWidget(
                onSearchChanged: (query) {
                  ref.read(birthdaySearchProvider.notifier).update(query);
                },
                onAddPressed: () => BirthdayFormSheet.show(context),
              ),
              const SizedBox(height: 12),
              const _CategoryFilterBar(),
              const SizedBox(height: 20),
              Expanded(
                child: _HomeContent(
                  isLoading: isLoading,
                  birthdays: filteredBirthdays,
                ),
              ),
            ],
          ),
        ),
      ),
      // bottomNavigationBar: const BottomBar(),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.isLoading, required this.birthdays});

  final bool isLoading;
  final List<BirthdayModel> birthdays;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (birthdays.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noBirthdaysFound,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ContactSections(birthdays: birthdays);
  }
}

class _CategoryFilterBar extends ConsumerWidget {
  const _CategoryFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategories = ref.watch(birthdayCategoryFilterProvider);
    final categories = ref.watch(categoriesProvider);

    return categories.when(
      data: (categoriesList) {
        final sortedCategories = List<BirthdayCategory>.from(categoriesList)
          ..sort(
            (a, b) => a
                .getLocalizedName(context)
                .toLowerCase()
                .compareTo(b.getLocalizedName(context).toLowerCase()),
          );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...sortedCategories.map((cat) {
                final isSelected = selectedCategories.contains(cat.id);
                final colorScheme = Theme.of(context).colorScheme;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      cat.getLocalizedName(context),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    avatar: Icon(
                      cat.iconData,
                      size: 16,
                      color:
                          isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.primary,
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      final currentState = ref.read(
                        birthdayCategoryFilterProvider,
                      );

                      if (selected) {
                        ref
                            .read(birthdayCategoryFilterProvider.notifier)
                            .update([...currentState, cat.id]);
                      } else {
                        ref
                            .read(birthdayCategoryFilterProvider.notifier)
                            .update(
                              currentState.where((id) => id != cat.id).toList(),
                            );
                      }
                    },
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }),
              // Bouton d'ajout de catégorie
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: const Icon(Icons.add, size: 18),
                  onPressed: () => CategoryFormSheet.show(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 32),
      error: (e, s) => const SizedBox(),
    );
  }
}
