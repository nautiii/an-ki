import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_model.dart';
import 'package:an_ki/features/user/providers/account_deletion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

const _user = UserModel(
  id: 'user-1',
  name: 'Quentin',
  surname: 'Maillard',
  isDark: false,
  locale: 'fr',
);

void main() {
  late RecordingBirthdayRepository birthdays;
  late RecordingUserRepository users;

  ProviderContainer makeContainer({String? uid = 'user-1'}) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        birthdayRepositoryProvider.overrideWithValue(birthdays),
        userRepositoryProvider.overrideWithValue(users),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    container.listen(accountDeletionProvider, (_, _) {});
    return container;
  }

  setUp(() {
    birthdays = RecordingBirthdayRepository();
    users = RecordingUserRepository(stored: _user);
  });

  test('erases the birthdays, then the profile', () async {
    final container = makeContainer();

    await container.read(accountDeletionProvider.notifier).eraseData();

    expect(birthdays.erasedUids, ['user-1']);
    expect(users.deleted, ['user-1']);
    expect(container.read(accountDeletionProvider), isA<AsyncData<void>>());
  });

  test('does nothing without a session', () async {
    final container = makeContainer(uid: null);

    await container.read(accountDeletionProvider.notifier).eraseData();

    expect(birthdays.erasedUids, isEmpty);
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
