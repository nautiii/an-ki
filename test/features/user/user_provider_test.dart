import 'package:an_ki/features/birthday/data/repositories/birthday_repository.dart';
import 'package:an_ki/features/user/data/models/user_model.dart';
import 'package:an_ki/features/user/data/repositories/user_repository.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';

class RecordingUserRepository extends FakeUserRepository {
  RecordingUserRepository({this.stored, this.throwOnFetch = false});

  UserModel? stored;
  final bool throwOnFetch;
  UserModel? existingOnCreate;
  final List<UserModel> created = [];
  final List<UserModel> updated = [];
  final List<String> deleted = [];

  @override
  Future<UserModel?> fetchUser(String uid) async {
    if (throwOnFetch) throw Exception('boom');
    return stored;
  }

  @override
  Future<UserModel> createUser(UserModel user) async {
    created.add(user);
    // Mirrors the real create-if-absent: returns the existing user if present.
    return existingOnCreate ?? user;
  }

  @override
  Future<void> updateUser(UserModel user) async {
    updated.add(user);
    stored = user;
  }

  @override
  Future<void> deleteUser(String uid) async => deleted.add(uid);
}

const _user = UserModel(
  id: 'user-1',
  name: 'Quentin',
  surname: 'Maillard',
  isDark: false,
  locale: 'fr',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer(RecordingUserRepository repo) {
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(repo),
        birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('loadUser', () {
    test('loads the user and clears loading', () async {
      final repo = RecordingUserRepository(stored: _user);
      final container = makeContainer(repo);

      await container.read(userProvider.notifier).loadUser('user-1');

      expect(container.read(userProvider).user, _user);
      expect(container.read(userProvider).isLoading, false);
    });

    test('swallows errors and clears loading', () async {
      final repo = RecordingUserRepository(throwOnFetch: true);
      final container = makeContainer(repo);

      await container.read(userProvider.notifier).loadUser('user-1');

      expect(container.read(userProvider).isLoading, false);
    });
  });

  test('createUser persists a new user and updates the state', () async {
    final repo = RecordingUserRepository();
    final container = makeContainer(repo);

    await container
        .read(userProvider.notifier)
        .createUser(uid: 'user-1', name: 'New', surname: 'User');

    expect(repo.created, hasLength(1));
    expect(container.read(userProvider).user?.name, 'New');
  });

  test(
    'createUser adopts the existing profile instead of the default',
    () async {
      final repo =
          RecordingUserRepository()
            ..existingOnCreate = _user.copyWith(pseudo: 'Quentinou');
      final container = makeContainer(repo);

      await container
          .read(userProvider.notifier)
          .createUser(uid: 'user-1', name: 'guest', surname: '');

      // The notifier reflects the preserved profile, not the blank guest.
      expect(container.read(userProvider).user?.name, 'Quentin');
      expect(container.read(userProvider).user?.pseudo, 'Quentinou');
    },
  );

  group('mutations require an existing user', () {
    test(
      'updatePseudo / updateTheme / updateLocale are no-ops when null',
      () async {
        final repo = RecordingUserRepository();
        final container = makeContainer(repo);
        final notifier = container.read(userProvider.notifier);

        await notifier.updatePseudo('p');
        await notifier.updateTheme(true);
        await notifier.updateLocale('en');

        expect(repo.updated, isEmpty);
      },
    );

    test('they update the user when present', () async {
      final repo = RecordingUserRepository(stored: _user);
      final container = makeContainer(repo);
      final notifier = container.read(userProvider.notifier);
      await notifier.loadUser('user-1');

      await notifier.updatePseudo('Q');
      await notifier.updateTheme(true);
      await notifier.updateLocale('en');

      final user = container.read(userProvider).user!;
      expect(user.pseudo, 'Q');
      expect(user.isDark, true);
      expect(user.locale, 'en');
      expect(repo.updated, hasLength(3));
    });
  });

  test('deleteAccount wipes birthdays, the user and local state', () async {
    final repo = RecordingUserRepository(stored: _user);
    final container = makeContainer(repo);
    final notifier = container.read(userProvider.notifier);
    await notifier.loadUser('user-1');

    await notifier.deleteAccount('user-1');

    expect(repo.deleted, ['user-1']);
    expect(container.read(userProvider).user, isNull);
    expect(container.read(userProvider).isLoading, false);
  });

  test('clear resets the state', () async {
    final repo = RecordingUserRepository(stored: _user);
    final container = makeContainer(repo);
    await container.read(userProvider.notifier).loadUser('user-1');

    container.read(userProvider.notifier).clear();

    expect(container.read(userProvider).user, isNull);
  });
}
