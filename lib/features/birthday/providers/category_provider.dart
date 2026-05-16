import 'package:an_ki/data/models/category_model.dart';
import 'package:an_ki/data/repositories/category_repository.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/data/repositories/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final categoriesProvider = StreamProvider<List<BirthdayCategory>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategories().map((categories) {
    final sorted = List<BirthdayCategory>.from(categories);
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  });
});

/// Provider pour les catégories sélectionnées par l'utilisateur
final userCategoriesProvider = Provider<List<BirthdayCategory>>((ref) {
  final allCategories = ref.watch(categoriesProvider).value ?? [];
  final user = ref.watch(userProvider).user;
  if (user == null) return [];

  final filtered =
      allCategories.where((cat) => user.categories.contains(cat.id)).toList();

  // On trie par nom technique (puisque le context n'est pas disponible ici pour le localisé)
  return filtered
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

class CategoryNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> addCategoriesToUser(List<String> categoryIds) async {
    final user = ref.read(userProvider).user;
    if (user == null) return;

    final updatedCategories = {...user.categories, ...categoryIds}.toList();
    final updatedUser = user.copyWith(categories: updatedCategories);
    
    await ref.read(userRepositoryProvider).updateUser(updatedUser);
    await ref.read(userProvider.notifier).loadUser(user.id);
  }

  Future<void> createAndAddCategory(String name, int icon) async {
    final user = ref.read(userProvider).user;
    if (user == null) return;

    final category = BirthdayCategory(id: '', name: name, icon: icon);
    final newCategoryId = await ref.read(categoryRepositoryProvider).createCategory(category);
    
    await addCategoriesToUser([newCategoryId]);
  }
}

final categoryNotifierProvider = NotifierProvider<CategoryNotifier, void>(
  CategoryNotifier.new,
);
