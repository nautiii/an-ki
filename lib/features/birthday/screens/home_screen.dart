import 'package:an_ki/core/common/anki_empty_state.dart';
import 'package:an_ki/core/common/bottom_bar.dart';
import 'package:an_ki/core/common/header.dart';
import 'package:an_ki/core/common/search_bar.dart';
import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/core/constants/app_assets.dart';
import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_editor.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_editor.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/providers/home_view_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_calendar.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:an_ki/features/birthday/widgets/category_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/contact_sections.dart';
import 'package:an_ki/features/birthday/widgets/next_birthday.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Les écritures sont optimistes (la feuille se ferme sans attendre) :
    // l'accueil, toujours monté dessous, annonce un échec tardif. Il remplace
    // le message en cours (« … supprimé ») que l'échec contredit.
    ref.listen(birthdayEditorProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.l10n.errorSavingBirthday)),
          );
      }
    });
    ref.listen(categoryEditorProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorSavingCategory)),
        );
      }
    });
    final filteredBirthdays = ref.watch(filteredBirthdaysProvider);
    final isLoading = ref.watch(birthdaysLoadingProvider);
    final hasBirthdays = ref.watch(
      birthdaysListProvider.select((birthdays) => birthdays.isNotEmpty),
    );
    final viewType = ref.watch(homeViewProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Header(
                userName: ref.watch(
                  userProfileProvider.select(
                    (profile) => profile.value?.displayName,
                  ),
                ),
                isListView: viewType == HomeViewType.list,
                onToggleView: () =>
                    ref.read(homeViewProvider.notifier).toggle(),
                onOpenSettings: () => context.push(AppRoutes.settings),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Le héros n'existe qu'avec des anniversaires (ou leur squelette).
              if (isLoading || hasBirthdays) ...[
                const NextBirthdayCard(),
                const SizedBox(height: AppSpacing.md),
              ],
              SearchBarWidget(
                onSearchChanged: (query) {
                  ref.read(birthdaySearchProvider.notifier).update(query);
                },
                onAddPressed: () => BirthdayFormSheet.show(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              const _CategoryFilterBar(),
              const SizedBox(height: AppSpacing.xxs),
              Expanded(
                child: AnimatedSwitcher(
                  duration: context.motion(AppMotion.enter),
                  child: _HomeContent(
                    key: ValueKey(viewType),
                    isLoading: isLoading,
                    hasBirthdays: hasBirthdays,
                    birthdays: filteredBirthdays,
                    viewType: viewType,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    super.key,
    required this.isLoading,
    required this.hasBirthdays,
    required this.birthdays,
    required this.viewType,
  });

  final bool isLoading;

  /// L'utilisateur a au moins un anniversaire, filtres et recherche ignorés.
  final bool hasBirthdays;
  final List<Birthday> birthdays;
  final HomeViewType viewType;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _ListSkeleton();

    if (viewType == HomeViewType.calendar) {
      return const Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: BottomBar.overlap,
          ),
          child: BirthdayCalendar(),
        ),
      );
    }

    // Premier lancement : rien à chercher, on invite à ajouter.
    if (!hasBirthdays) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(
          top: AppSpacing.xl,
          bottom: BottomBar.overlap,
        ),
        child: AnKiEmptyState(
          illustration: Image.asset(AppAssets.moon),
          title: context.l10n.emptyBirthdaysTitle,
          message: context.l10n.emptyBirthdaysMessage,
          primaryLabel: context.l10n.addBirthday,
          onPrimary: () => BirthdayFormSheet.show(context),
        ),
      );
    }

    if (birthdays.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Text(
          context.l10n.noBirthdaysFound,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ContactSections(birthdays: birthdays);
  }
}

/// Squelette de la liste, à la forme des tuiles attendues.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    // En haut, comme la liste qu'il annonce (l'AnimatedSwitcher centre).
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Column(
          spacing: AppSpacing.xs,
          children: [
            for (var i = 0; i < 4; i++)
              const SkeletonBox(height: 72, radius: AppRadii.lg),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilterBar extends ConsumerWidget {
  const _CategoryFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategories = ref.watch(birthdayCategoryFilterProvider);
    final userCategories = ref.watch(userCategoriesProvider);

    if (userCategories.isEmpty) {
      return ActionChip(
        avatar: const Icon(Icons.add_rounded),
        label: Text(context.l10n.newCategory),
        onPressed: () => CategoryFormSheet.show(context),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: AppSpacing.xs,
        children: [
          for (final category in userCategories)
            ChoiceChip(
              avatar: Icon(category.iconData),
              label: Text(category.localizedName(context)),
              selected: selectedCategories.contains(category.id),
              onSelected: (selected) {
                ref.read(birthdayCategoryFilterProvider.notifier).update([
                  for (final id in selectedCategories)
                    if (id != category.id) id,
                  if (selected) category.id,
                ]);
              },
            ),
          ActionChip(
            label: const Icon(Icons.add_rounded),
            tooltip: context.l10n.newCategory,
            onPressed: () => CategoryFormSheet.show(context),
          ),
        ],
      ),
    );
  }
}
