import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
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
