import 'package:an_ki/features/birthday/data/models/category_model.dart';
import 'package:an_ki/features/birthday/data/repositories/category_repository.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/user/data/models/user_model.dart';
import 'package:an_ki/features/user/data/repositories/user_repository.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

class StubUserRepository implements UserRepository {
  StubUserRepository(this._stored);

  UserModel? _stored;
  final List<UserModel> updated = [];

  @override
  Future<UserModel?> fetchUser(String uid) async => _stored;

  @override
  Future<void> updateUser(UserModel user) async {
    updated.add(user);
    _stored = user;
  }

  @override
  Future<UserModel> createUser(UserModel user) async => user;

  @override
  Future<void> updateBiometricToken(String uid, String? token) async {}

  @override
  Future<UserModel?> fetchUserByToken(String uid, String token) async => null;

  @override
  Future<void> deleteUser(String uid) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final family = BirthdayCategory(id: 'fam', name: 'Family', icon: 1);
  final friend = BirthdayCategory(id: 'fri', name: 'Apple', icon: 2);

  ProviderContainer makeContainer({
    required List<BirthdayCategory> categories,
    UserModel? storedUser,
  }) {
    final container = ProviderContainer(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(
          StubCategoryRepository(categories),
        ),
        userRepositoryProvider.overrideWithValue(
          StubUserRepository(storedUser),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Subscribes to [categoriesProvider] (so the underlying stream is listened
  /// to) and waits for its first emission.
  Future<void> primeCategories(ProviderContainer container) async {
    final sub = container.listen(categoriesProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(categoriesProvider.future);
  }

  group('categoriesProvider', () {
    test('emits categories sorted alphabetically (case-insensitive)', () async {
      final container = makeContainer(categories: [family, friend]);

      await primeCategories(container);
      final result = container.read(categoriesProvider).value!;

      expect(result.map((c) => c.name), ['Apple', 'Family']);
    });
  });

  group('userCategoriesProvider', () {
    test('is empty when there is no user', () async {
      final container = makeContainer(categories: [family, friend]);
      await primeCategories(container);

      expect(container.read(userCategoriesProvider), isEmpty);
    });

    test('keeps only the categories selected by the user', () async {
      const user = UserModel(
        id: 'u',
        name: 'A',
        surname: 'B',
        categories: ['fam'],
        isDark: false,
        locale: 'fr',
      );
      final container = makeContainer(
        categories: [family, friend],
        storedUser: user,
      );
      await primeCategories(container);
      await container.read(userProvider.notifier).loadUser('u');

      final result = container.read(userCategoriesProvider);

      expect(result.map((c) => c.id), ['fam']);
    });
  });

  group('CategoryNotifier', () {
    test('addCategoriesToUser is a no-op without a user', () async {
      final repo = StubUserRepository(null);
      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(
            StubCategoryRepository(const []),
          ),
          userRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(categoryNotifierProvider.notifier)
          .addCategoriesToUser(['x']);

      expect(repo.updated, isEmpty);
    });

    test('addCategoriesToUser merges and persists the ids', () async {
      const user = UserModel(
        id: 'u',
        name: 'A',
        surname: 'B',
        categories: ['fam'],
        isDark: false,
        locale: 'fr',
      );
      final repo = StubUserRepository(user);
      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(
            StubCategoryRepository(const []),
          ),
          userRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(userProvider.notifier).loadUser('u');

      await container
          .read(categoryNotifierProvider.notifier)
          .addCategoriesToUser(['fri']);

      expect(repo.updated.last.categories.toSet(), {'fam', 'fri'});
    });

    test('createAndAddCategory creates the category then links it', () async {
      const user = UserModel(
        id: 'u',
        name: 'A',
        surname: 'B',
        isDark: false,
        locale: 'fr',
      );
      final categoryRepo = StubCategoryRepository(const []);
      final userRepo = StubUserRepository(user);
      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(categoryRepo),
          userRepositoryProvider.overrideWithValue(userRepo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(userProvider.notifier).loadUser('u');

      await container
          .read(categoryNotifierProvider.notifier)
          .createAndAddCategory('Work', 42);

      expect(categoryRepo.created.single.name, 'Work');
      expect(userRepo.updated.last.categories, contains('new-id'));
    });

    test('createAndAddCategory is a no-op without a user', () async {
      final categoryRepo = StubCategoryRepository(const []);
      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(categoryRepo),
          userRepositoryProvider.overrideWithValue(StubUserRepository(null)),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(categoryNotifierProvider.notifier)
          .createAndAddCategory('Work', 42);

      expect(categoryRepo.created, isEmpty);
    });
  });
}
