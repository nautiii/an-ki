import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_groups.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:an_ki/features/birthday/providers/group_entries.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

void main() {
  const family = BirthdayCategory(id: 'fam', name: 'family', icon: 1);
  const goat = BirthdayCategory(id: 'goat', name: 'goat', icon: 3);
  const book = BirthdayCategory(id: 'book', name: 'Club de lecture', icon: 5);

  test('lists the user groups with their kind and count', () async {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        categoryRepositoryProvider.overrideWithValue(
          RecordingCategoryRepository([family, goat], own: [book]),
        ),
        userRepositoryProvider.overrideWithValue(
          RecordingUserRepository(
            stored: const UserProfile(
              id: 'u',
              name: 'A',
              surname: 'B',
              categories: ['goat'],
              locale: 'fr',
            ),
          ),
        ),
        birthdayRepositoryProvider.overrideWithValue(
          RecordingBirthdayRepository(
            initial: const [
              Birthday(
                id: '1',
                name: 'Léa',
                surname: '',
                date: BirthDate(month: 3, day: 12),
                categories: ['book', 'fam'],
              ),
            ],
          ),
        ),
        currentUidProvider.overrideWithValue('u'),
      ],
    );
    container.listen(groupEntriesProvider, (_, _) {});
    await container.read(userProfileProvider.future);
    await container.read(sharedCategoriesProvider.future);
    await container.read(ownCategoriesProvider.future);
    await container.read(birthdaysProvider.future);

    expect(container.read(groupEntriesProvider).value, const [
      GroupEntry(category: family, kind: GroupKind.preset, count: 1),
      GroupEntry(category: book, kind: GroupKind.own, count: 1),
      GroupEntry(category: goat, kind: GroupKind.shared, count: 0),
    ]);
  });

  ProviderContainer plain({required RecordingCategoryRepository categories}) =>
      ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          categoryRepositoryProvider.overrideWithValue(categories),
          userRepositoryProvider.overrideWithValue(
            RecordingUserRepository(
              stored: const UserProfile(
                id: 'u',
                name: 'A',
                surname: 'B',
                locale: 'fr',
              ),
            ),
          ),
          birthdayRepositoryProvider.overrideWithValue(
            RecordingBirthdayRepository(),
          ),
          currentUidProvider.overrideWithValue('u'),
        ],
      );

  test('is loading until the groups arrive', () {
    final container = plain(categories: RecordingCategoryRepository([family]));
    container.listen(groupEntriesProvider, (_, _) {});

    expect(container.read(groupEntriesProvider), isA<AsyncLoading<void>>());
  });

  test('fails when the shared groups cannot be read', () async {
    final container = plain(
      categories: RecordingCategoryRepository(
        const [],
        watchError: Exception('unavailable'),
      ),
    );
    container.listen(groupEntriesProvider, (_, _) {});
    await pumpEventQueue();

    expect(container.read(groupEntriesProvider).hasError, isTrue);
  });
}
