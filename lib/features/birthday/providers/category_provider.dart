import 'package:an_ki/data/models/category_model.dart';
import 'package:an_ki/data/repositories/category_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final categoriesProvider = StreamProvider<List<BirthdayCategory>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategories();
});

class CategoryNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> addCategory(String name, int icon) async {
    final category = BirthdayCategory(id: '', name: name, icon: icon);
    await ref.read(categoryRepositoryProvider).createCategory(category);
  }
}

final categoryNotifierProvider = NotifierProvider<CategoryNotifier, void>(
  CategoryNotifier.new,
);
