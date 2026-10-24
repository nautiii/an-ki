import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/settings/providers/account_deletion.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

const _user = UserProfile(
  id: 'user-1',
  name: 'Quentin',
  surname: 'Maillard',
  locale: 'fr',
);

void main() {
  late RecordingBirthdayRepository birthdays;
  late RecordingBookRepository books;
  late RecordingCategoryRepository categories;
  late RecordingUserRepository users;

  ProviderContainer makeContainer({String? uid = 'user-1'}) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        birthdayRepositoryProvider.overrideWithValue(birthdays),
        bookRepositoryProvider.overrideWithValue(books),
        categoryRepositoryProvider.overrideWithValue(categories),
        userRepositoryProvider.overrideWithValue(users),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    container.listen(accountDeletionProvider, (_, _) {});
    return container;
  }

  setUp(() {
    birthdays = RecordingBirthdayRepository();
    books = RecordingBookRepository();
    categories = RecordingCategoryRepository(const []);
    users = RecordingUserRepository(stored: _user);
  });

  test(
    'erases the birthdays, the books, the groups, then the profile',
    () async {
      final container = makeContainer();

      await container.read(accountDeletionProvider.notifier).eraseData();

      expect(birthdays.erasedUids, ['user-1']);
      expect(books.erasedUids, ['user-1']);
      expect(categories.erasedUids, ['user-1']);
      expect(users.deleted, ['user-1']);
      expect(container.read(accountDeletionProvider), isA<AsyncData<void>>());
    },
  );

  test('does nothing without a session', () async {
    final container = makeContainer(uid: null);

    await container.read(accountDeletionProvider.notifier).eraseData();

    expect(birthdays.erasedUids, isEmpty);
    expect(books.erasedUids, isEmpty);
    expect(categories.erasedUids, isEmpty);
    expect(users.deleted, isEmpty);
  });

  test('keeps the profile when the books cannot be erased', () async {
    books = RecordingBookRepository(failure: Exception('denied'));
    final container = makeContainer();

    await expectLater(
      container.read(accountDeletionProvider.notifier).eraseData(),
      throwsException,
    );
    expect(users.deleted, isEmpty);
  });

  test('keeps the profile when the groups cannot be erased', () async {
    categories = RecordingCategoryRepository(
      const [],
      failure: Exception('denied'),
    );
    final container = makeContainer();

    await expectLater(
      container.read(accountDeletionProvider.notifier).eraseData(),
      throwsException,
    );
    expect(users.deleted, isEmpty);
  });

  test('stops and rethrows when a deletion fails', () async {
    birthdays = RecordingBirthdayRepository(failure: Exception('denied'));
    final container = makeContainer();

    await expectLater(
      container.read(accountDeletionProvider.notifier).eraseData(),
      throwsException,
    );
    expect(users.deleted, isEmpty);
    expect(container.read(accountDeletionProvider).hasError, isTrue);
  });
}
