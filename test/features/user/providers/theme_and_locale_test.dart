import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/locale_provider.dart';
import 'package:an_ki/features/user/providers/theme_provider.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

UserProfile _user({
  ThemePreference theme = ThemePreference.system,
  String locale = 'fr',
}) =>
    UserProfile(id: 'u', name: 'A', surname: 'B', theme: theme, locale: locale);

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

    test('reflects each profile preference', () async {
      final expected = {
        ThemePreference.system: ThemeMode.system,
        ThemePreference.light: ThemeMode.light,
        ThemePreference.dark: ThemeMode.dark,
      };
      for (final MapEntry(key: theme, value: mode) in expected.entries) {
        final container = await makeContainer(_user(theme: theme));

        expect(container.read(themeProvider), mode, reason: '$theme');
      }
    });

    test('switches as soon as the profile is edited', () async {
      final container = await makeContainer(_user());
      container.listen(userProfileEditorProvider, (_, _) {});
      expect(container.read(themeProvider), ThemeMode.system);

      await container
          .read(userProfileEditorProvider.notifier)
          .setTheme(ThemePreference.dark);
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
