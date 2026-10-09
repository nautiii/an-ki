import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_model.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';

class StubCategoryRepository implements CategoryRepository {
  StubCategoryRepository(this.categories);

  final List<BirthdayCategory> categories;
  final List<BirthdayCategory> created = [];

  @override
  Stream<List<BirthdayCategory>> watchCategories() => Stream.value(categories);

  @override
  Future<String> createCategory(BirthdayCategory category) async {
    created.add(category);
    return 'new-id';
  }
}

const _user = UserModel(
  id: 'u',
  name: 'A',
  surname: 'B',
  categories: ['fam'],
  isDark: false,
  locale: 'fr',
);

void main() {
  const family = BirthdayCategory(id: 'fam', name: 'Family', icon: 1);
  const friend = BirthdayCategory(id: 'fri', name: 'Apple', icon: 2);

  /// Conteneur avec la session `u` ; attend le premier profil (Riverpod 3 met
  /// en pause un flux sans listener, d'où l'écoute).
  Future<ProviderContainer> makeContainer({
    required StubCategoryRepository categories,
    required RecordingUserRepository users,
  }) async {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        categoryRepositoryProvider.overrideWithValue(categories),
        userRepositoryProvider.overrideWithValue(users),
        currentUidProvider.overrideWithValue('u'),
      ],
    );
    container.listen(userProfileProvider, (_, _) {});
    container.listen(categoriesProvider, (_, _) {});
    await container.read(userProfileProvider.future);
    await container.read(categoriesProvider.future);
    return container;
  }

  group('categoriesProvider', () {
    test('emits categories sorted alphabetically (case-insensitive)', () async {
      final container = await makeContainer(
        categories: StubCategoryRepository([family, friend]),
        users: RecordingUserRepository(),
      );

      final result = container.read(categoriesProvider).value!;

      expect(result.map((c) => c.name), ['Apple', 'Family']);
    });
  });

  group('userCategoriesProvider', () {
    test('is empty when there is no profile', () async {
      final container = await makeContainer(
        categories: StubCategoryRepository([family, friend]),
        users: RecordingUserRepository(),
      );

      expect(container.read(userCategoriesProvider), isEmpty);
    });

    test('keeps only the categories selected by the user', () async {
      final container = await makeContainer(
        categories: StubCategoryRepository([family, friend]),
        users: RecordingUserRepository(stored: _user),
      );

      final result = container.read(userCategoriesProvider);

      expect(result.map((c) => c.id), ['fam']);
    });
  });

  group('CategoryNotifier', () {
    test('addCategoriesToUser is a no-op without a profile', () async {
      final users = RecordingUserRepository();
      final container = await makeContainer(
        categories: StubCategoryRepository(const []),
        users: users,
      );

      await container
          .read(categoryNotifierProvider.notifier)
          .addCategoriesToUser(['x']);

      expect(users.updated, isEmpty);
    });

    test('addCategoriesToUser merges and persists the ids', () async {
      final users = RecordingUserRepository(stored: _user);
      final container = await makeContainer(
        categories: StubCategoryRepository(const []),
        users: users,
      );

      await container
          .read(categoryNotifierProvider.notifier)
          .addCategoriesToUser(['fri']);

      expect(users.stored?.categories.toSet(), {'fam', 'fri'});
    });

    test('createAndAddCategory creates the category then links it', () async {
      final categories = StubCategoryRepository(const []);
      final users = RecordingUserRepository(stored: _user);
      final container = await makeContainer(
        categories: categories,
        users: users,
      );

      await container
          .read(categoryNotifierProvider.notifier)
          .createAndAddCategory('Work', 42);

      expect(categories.created.single.name, 'Work');
      expect(users.stored?.categories, contains('new-id'));
    });

    test('createAndAddCategory is a no-op without a profile', () async {
      final categories = StubCategoryRepository(const []);
      final container = await makeContainer(
        categories: categories,
        users: RecordingUserRepository(),
      );

      await container
          .read(categoryNotifierProvider.notifier)
          .createAndAddCategory('Work', 42);

      expect(categories.created, isEmpty);
    });
  });
}
