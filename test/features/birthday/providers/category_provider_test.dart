import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

const _user = UserProfile(
  id: 'u',
  name: 'A',
  surname: 'B',
  categories: ['goat'],
  locale: 'fr',
);

void main() {
  const family = BirthdayCategory(id: 'fam', name: 'family', icon: 1);
  const other = BirthdayCategory(id: 'oth', name: 'other', icon: 2);
  const goat = BirthdayCategory(id: 'goat', name: 'goat', icon: 3);
  const sport = BirthdayCategory(id: 'spo', name: 'sport', icon: 4);
  const book = BirthdayCategory(id: 'book', name: 'Club de lecture', icon: 5);

  /// Conteneur avec la session [uid] ; attend le profil et les catégories
  /// (Riverpod 3 met en pause un flux sans listener, d'où l'écoute).
  Future<ProviderContainer> makeContainer({
    required RecordingCategoryRepository categories,
    RecordingUserRepository? users,
    String? uid = 'u',
  }) async {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        categoryRepositoryProvider.overrideWithValue(categories),
        userRepositoryProvider.overrideWithValue(
          users ?? RecordingUserRepository(stored: _user),
        ),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    container
      ..listen(userProfileProvider, (_, _) {})
      ..listen(categoriesProvider, (_, _) {})
      ..listen(userCategoriesProvider, (_, _) {});
    await container.read(userProfileProvider.future);
    await container.read(sharedCategoriesProvider.future);
    await container.read(ownCategoriesProvider.future);
    return container;
  }

  group('categoriesProvider', () {
    test('holds the shared categories and the private groups', () async {
      final container = await makeContainer(
        categories: RecordingCategoryRepository([family, goat], own: [book]),
      );

      expect(container.read(categoriesProvider), [family, goat, book]);
    });

    test('holds no private group without a session', () async {
      final container = await makeContainer(
        categories: RecordingCategoryRepository([family], own: [book]),
        uid: null,
      );

      expect(container.read(categoriesProvider), [family]);
    });
  });

  group('userCategoriesProvider', () {
    test('is empty when there is no profile', () async {
      final container = await makeContainer(
        categories: RecordingCategoryRepository([family, other]),
        users: RecordingUserRepository(),
      );

      expect(container.read(userCategoriesProvider), isEmpty);
    });

    test('offers the defaults, then the picked and private groups', () async {
      final container = await makeContainer(
        categories: RecordingCategoryRepository(
          [family, other, goat, sport],
          own: [book],
        ),
      );

      expect(container.read(userCategoriesProvider), [
        family,
        book,
        goat,
        other,
      ]);
    });

    test('shows a group as soon as it is created', () async {
      final categories = RecordingCategoryRepository([family]);
      final container = await makeContainer(categories: categories);

      await categories.createCategory('u', book);
      await pumpEventQueue();

      expect(container.read(userCategoriesProvider), [family, book]);
    });
  });
}
