import 'package:an_ki/features/birthday/data/models/category_model.dart';
import 'package:an_ki/features/birthday/data/repositories/category_repository.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/features/user/data/repositories/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final categoriesProvider = StreamProvider<List<BirthdayCategory>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategories().map((
    categories,
  ) {
    final sorted = List<BirthdayCategory>.from(categories);
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  });
});

/// Provider pour les catégories sélectionnées par l'utilisateur
final userCategoriesProvider = Provider<List<BirthdayCategory>>((ref) {
  final allCategories = ref.watch(categoriesProvider).value ?? [];
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return [];

  final filtered = allCategories
      .where((cat) => user.categories.contains(cat.id))
      .toList();

  // On trie par nom technique (puisque le context n'est pas disponible ici pour le localisé)
  return filtered
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

class CategoryNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Ajoute des catégories au profil (union, sans doublon) ; le flux du profil
  /// se met à jour seul.
  Future<void> addCategoriesToUser(List<String> categoryIds) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    await ref.read(userRepositoryProvider).addCategories(user.id, categoryIds);
  }

  Future<void> createAndAddCategory(String name, int icon) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    final category = BirthdayCategory(id: '', name: name, icon: icon);
    final newCategoryId = await ref
        .read(categoryRepositoryProvider)
        .createCategory(category);

    await addCategoriesToUser([newCategoryId]);
  }
}

final categoryNotifierProvider = NotifierProvider<CategoryNotifier, void>(
  CategoryNotifier.new,
);
