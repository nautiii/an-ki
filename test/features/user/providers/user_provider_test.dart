import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

const _user = UserProfile(
  id: 'user-1',
  name: 'Quentin',
  surname: 'Maillard',
  isDark: false,
  locale: 'fr',
);

void main() {
  ProviderContainer makeContainer(
    RecordingUserRepository repo, {
    String? uid = 'user-1',
  }) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        userRepositoryProvider.overrideWithValue(repo),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    // Riverpod 3 met en pause un StreamProvider sans listener.
    container.listen(userProfileProvider, (_, _) {});
    return container;
  }

  test('streams the profile of the signed-in user', () async {
    final container = makeContainer(RecordingUserRepository(stored: _user));

    expect(await container.read(userProfileProvider.future), _user);
  });

  test('is null without a session', () async {
    final container = makeContainer(
      RecordingUserRepository(stored: _user),
      uid: null,
    );

    expect(await container.read(userProfileProvider.future), isNull);
  });

  test('reflects a write at once, like the Firestore cache', () async {
    final repo = RecordingUserRepository(stored: _user);
    final container = makeContainer(repo);
    await container.read(userProfileProvider.future);

    await repo.updatePreferences('user-1', pseudo: 'Q');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(userProfileProvider).value?.pseudo, 'Q');
  });

  group('greetingNameProvider', () {
    ProviderContainer greetingContainer(
      UserProfile? profile, {
      bool guest = false,
    }) => ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        userProfileProvider.overrideWithValue(AsyncData(profile)),
        isGuestProvider.overrideWithValue(guest),
      ],
    );

    test('greets an account by its first name', () {
      expect(greetingContainer(_user).read(greetingNameProvider), 'Quentin');
    });

    test('greets a guest without « Invité »', () {
      const guestProfile = UserProfile(
        id: 'user-1',
        name: 'Invité',
        surname: '',
        isDark: false,
        locale: 'fr',
      );

      expect(
        greetingContainer(guestProfile, guest: true).read(greetingNameProvider),
        isNull,
      );
    });

    test('has no name before the profile exists', () {
      expect(greetingContainer(null).read(greetingNameProvider), isNull);
    });
  });
}
