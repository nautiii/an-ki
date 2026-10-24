import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
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
  Future<ProviderContainer> makeContainer(RecordingUserRepository repo) async {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        userRepositoryProvider.overrideWithValue(repo),
        currentUidProvider.overrideWithValue('user-1'),
      ],
    );
    container.listen(userProfileProvider, (_, _) {});
    container.listen(userProfileEditorProvider, (_, _) {});
    await container.read(userProfileProvider.future);
    return container;
  }

  test('updates the pseudo, the theme and the language', () async {
    final repo = RecordingUserRepository(stored: _user);
    final container = await makeContainer(repo);
    final editor = container.read(userProfileEditorProvider.notifier);

    await editor.updatePseudo('Q');
    await editor.setTheme(ThemePreference.dark);
    await editor.setLocale('en');

    expect(repo.stored?.pseudo, 'Q');
    expect(repo.stored?.theme, ThemePreference.dark);
    expect(repo.stored?.locale, 'en');
    expect(container.read(userProfileEditorProvider), isA<AsyncData<void>>());
  });

  test('does nothing while there is no profile', () async {
    final repo = RecordingUserRepository();
    final container = await makeContainer(repo);

    await container.read(userProfileEditorProvider.notifier).setLocale('en');

    expect(repo.updated, isEmpty);
  });

  test('publishes a failed write as an AsyncError', () async {
    final repo = RecordingUserRepository(
      stored: _user,
      failure: Exception('offline rules'),
    );
    final container = await makeContainer(repo);

    await container
        .read(userProfileEditorProvider.notifier)
        .setTheme(ThemePreference.light);

    expect(container.read(userProfileEditorProvider).hasError, isTrue);
  });
}
