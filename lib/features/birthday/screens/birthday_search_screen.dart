import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/widgets/agenda_tile.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/category_display.dart';
import 'package:an_ki/features/birthday/widgets/category_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Recherche dans tout le carnet (héros compris) : par nom, filtrée par
/// catégories. Sans résultat, propose de créer la personne cherchée.
///
/// Le texte et les filtres vivent dans des providers `autoDispose` : ils
/// repartent de zéro à chaque ouverture.
class BirthdaySearchScreen extends ConsumerStatefulWidget {
  const BirthdaySearchScreen({super.key});

  @override
  ConsumerState<BirthdaySearchScreen> createState() =>
      _BirthdaySearchScreenState();
}

class _BirthdaySearchScreenState extends ConsumerState<BirthdaySearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(birthdaySearchProvider.notifier).update('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = ref.watch(birthdaySearchProvider);
    final filters = ref.watch(birthdayCategoryFilterProvider);
    final results = ref.watch(birthdaySearchResultsProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                0,
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: ref.read(birthdaySearchProvider.notifier).update,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadii.xl),
                    ),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: IconButton(
                    onPressed: () => context.pop(),
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _clear,
                          tooltip: l10n.clearSearch,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            _CategoryFilters(selected: filters),
            Expanded(
              child: results.isEmpty
                  ? _NoResults(
                      query: query.trim(),
                      hasFilters: filters.isNotEmpty,
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        AppSpacing.xs,
                        AppSpacing.gutter,
                        bottomInset + AppSpacing.md,
                      ),
                      itemCount: results.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) => AgendaTile(
                        key: ValueKey(results[index].id),
                        birthday: results[index],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filtres par catégorie (toutes requises), puis la création d'une catégorie.
class _CategoryFilters extends ConsumerWidget {
  const _CategoryFilters({required this.selected});

  final List<String> selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<BirthdayCategory> categories = ref.watch(userCategoriesProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        spacing: AppSpacing.xs,
        children: [
          for (final category in categories)
            FilterChip(
              label: Text(category.localizedName(context)),
              selected: selected.contains(category.id),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                ref
                    .read(birthdayCategoryFilterProvider.notifier)
                    .toggle(category.id);
              },
            ),
          ActionChip(
            avatar: const Icon(Icons.add_rounded),
            label: Text(context.l10n.newCategory),
            onPressed: () => CategoryFormSheet.show(context),
          ),
        ],
      ),
    );
  }
}

/// Aucun résultat : créer la personne cherchée, ou retirer les filtres.
class _NoResults extends ConsumerWidget {
  const _NoResults({required this.query, required this.hasFilters});

  final String query;
  final bool hasFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isEmpty && !hasFilters) return const SizedBox.shrink();
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xl,
        AppSpacing.gutter,
        MediaQuery.paddingOf(context).bottom + AppSpacing.md,
      ),
      child: Column(
        children: [
          Text(
            query.isEmpty ? l10n.noFilterResults : l10n.noSearchResults(query),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (query.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonalIcon(
              onPressed: () =>
                  BirthdayFormSheet.show(context, initialName: query),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addNamed(query)),
            ),
          ],
          if (hasFilters) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () =>
                  ref.read(birthdayCategoryFilterProvider.notifier).clear(),
              child: Text(l10n.clearFilters),
            ),
          ],
        ],
      ),
    );
  }
}
