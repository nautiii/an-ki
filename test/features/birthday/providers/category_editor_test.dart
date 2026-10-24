import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/providers/category_editor.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

const _user = UserProfile(
  id: 'u',
  name: 'A',
  surname: 'B',
  categories: ['fam'],
  locale: 'fr',
);

void main() {
  late RecordingCategoryRepository categories;
  late RecordingUserRepository users;

  ProviderContainer makeContainer({String? uid = 'u'}) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        categoryRepositoryProvider.overrideWithValue(categories),
        userRepositoryProvider.overrideWithValue(users),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    // Provider autoDispose : un listener le garde en vie pendant le test.
    container.listen(categoryEditorProvider, (_, _) {});
    return container;
  }

  setUp(() {
    categories = RecordingCategoryRepository(const []);
    users = RecordingUserRepository(stored: _user);
  });

  test('adds existing categories to the profile without duplicates', () async {
    final container = makeContainer();

    await container.read(categoryEditorProvider.notifier).addToProfile([
      'fam',
      'fri',
    ]);

    expect(users.stored?.categories, ['fam', 'fri']);
    expect(container.read(categoryEditorProvider), isA<AsyncData<void>>());
  });

  test('creates a category under a local id and links it', () async {
    final container = makeContainer();

    await container.read(categoryEditorProvider.notifier).create('Work', 42);

    expect(categories.created, [
      const BirthdayCategory(id: 'new-cat-1', name: 'Work', icon: 42),
    ]);
    expect(users.stored?.categories, ['fam', 'new-cat-1']);
  });

  test('does nothing without a session', () async {
    final container = makeContainer(uid: null);

    await container.read(categoryEditorProvider.notifier).create('Work', 42);

    expect(categories.created, isEmpty);
    expect(users.updated, isEmpty);
  });

  test('publishes a failed write as an AsyncError', () async {
    users = RecordingUserRepository(stored: _user, failure: Exception('rules'));
    final container = makeContainer();

    await container.read(categoryEditorProvider.notifier).addToProfile(['fri']);

    expect(container.read(categoryEditorProvider).hasError, isTrue);
  });
}
