import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/locale_provider.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

void main() {
  Future<ProviderContainer> makeContainer(UserProfile? stored) async {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        userRepositoryProvider.overrideWithValue(
          RecordingUserRepository(stored: stored),
        ),
        currentUidProvider.overrideWithValue('u'),
      ],
    );
    container.listen(localeProvider, (_, _) {});
    await container.read(userProfileProvider.future);
    return container;
  }

  group('localeProvider', () {
    test('defaults to French without a profile', () async {
      final container = await makeContainer(null);

      expect(container.read(localeProvider), const Locale('fr'));
    });

    test('reflects the profile language and its edits', () async {
      final container = await makeContainer(
        const UserProfile(id: 'u', name: 'A', surname: 'B', locale: 'en'),
      );
      container.listen(userProfileEditorProvider, (_, _) {});
      expect(container.read(localeProvider), const Locale('en'));

      await container.read(userProfileEditorProvider.notifier).setLocale('fr');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(localeProvider), const Locale('fr'));
    });
  });
}
