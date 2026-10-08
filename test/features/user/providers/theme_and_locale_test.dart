import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_model.dart';
import 'package:an_ki/features/user/providers/locale_provider.dart';
import 'package:an_ki/features/user/providers/theme_provider.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

UserModel _user({bool isDark = false, String locale = 'fr'}) =>
    UserModel(id: 'u', name: 'A', surname: 'B', isDark: isDark, locale: locale);

void main() {
  Future<ProviderContainer> makeContainer(UserModel? stored) async {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        userRepositoryProvider.overrideWithValue(
          RecordingUserRepository(stored: stored),
        ),
        currentUidProvider.overrideWithValue('u'),
      ],
    );
    container.listen(themeProvider, (_, _) {});
    container.listen(localeProvider, (_, _) {});
    await container.read(userProfileProvider.future);
    return container;
  }

  group('themeProvider', () {
    test('follows the system without a profile', () async {
      final container = await makeContainer(null);

      expect(container.read(themeProvider), ThemeMode.system);
    });

    test('reflects the profile preference', () async {
      final container = await makeContainer(_user(isDark: true));

      expect(container.read(themeProvider), ThemeMode.dark);
    });

    test('switches as soon as the profile is edited', () async {
      final container = await makeContainer(_user());
      container.listen(userProfileEditorProvider, (_, _) {});
      expect(container.read(themeProvider), ThemeMode.light);

      await container
          .read(userProfileEditorProvider.notifier)
          .setDarkMode(true);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(themeProvider), ThemeMode.dark);
    });
  });

  group('localeProvider', () {
    test('defaults to French without a profile', () async {
      final container = await makeContainer(null);

      expect(container.read(localeProvider), const Locale('fr'));
    });

    test('reflects the profile language and its edits', () async {
      final container = await makeContainer(_user(locale: 'en'));
      container.listen(userProfileEditorProvider, (_, _) {});
      expect(container.read(localeProvider), const Locale('en'));

      await container.read(userProfileEditorProvider.notifier).setLocale('fr');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(localeProvider), const Locale('fr'));
    });
  });
}
