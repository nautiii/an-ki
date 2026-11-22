import 'dart:async';

import 'package:an_ki/core/services/device_settings.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/theme_provider.dart';
import 'package:an_ki/features/user/providers/user_profile_editor.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

UserProfile _user({ThemePreference theme = ThemePreference.system}) =>
    UserProfile(id: 'u', name: 'A', surname: 'B', theme: theme, locale: 'fr');

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

    test('keeps the theme remembered on the phone while the profile loads', () {
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          userRepositoryProvider.overrideWithValue(_PendingUserRepository()),
          currentUidProvider.overrideWithValue('u'),
          rememberedThemeModeProvider.overrideWithValue(ThemeMode.dark),
        ],
      );
      container.listen(themeProvider, (_, _) {});

      expect(container.read(themeProvider), ThemeMode.dark);
    });

    test('the loaded profile wins over the remembered theme', () async {
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          userRepositoryProvider.overrideWithValue(
            RecordingUserRepository(
              stored: _user(theme: ThemePreference.light),
            ),
          ),
          currentUidProvider.overrideWithValue('u'),
          rememberedThemeModeProvider.overrideWithValue(ThemeMode.dark),
        ],
      );
      container.listen(themeProvider, (_, _) {});
      await container.read(userProfileProvider.future);

      expect(container.read(themeProvider), ThemeMode.light);
    });
  });

  test('keeps the last profile theme once the profile is gone', () async {
    final profiles = StreamController<UserProfile?>();
    addTearDown(profiles.close);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        userRepositoryProvider.overrideWithValue(
          _StreamedUserRepository(profiles.stream),
        ),
        currentUidProvider.overrideWithValue('u'),
        rememberedThemeModeProvider.overrideWithValue(ThemeMode.dark),
      ],
    );
    container.listen(themeProvider, (_, _) {});

    profiles.add(_user(theme: ThemePreference.light));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(themeProvider), ThemeMode.light);

    // Déconnexion : plus de profil, l'accueil garde le thème choisi.
    profiles.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(themeProvider), ThemeMode.light);
  });

  group('themeMemoryProvider', () {
    ProviderContainer makeMemory(
      RecordingUserRepository users,
      FakeDeviceSettings settings,
    ) {
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          userRepositoryProvider.overrideWithValue(users),
          currentUidProvider.overrideWithValue('u'),
          deviceSettingsProvider.overrideWithValue(settings),
        ],
      );
      container
        ..listen(themeMemoryProvider, (_, _) {})
        ..listen(userProfileEditorProvider, (_, _) {});
      return container;
    }

    test('keeps the theme of the loaded profile, then each change', () async {
      final settings = FakeDeviceSettings();
      final container = makeMemory(
        RecordingUserRepository(stored: _user(theme: ThemePreference.dark)),
        settings,
      );
      await container.read(userProfileProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(settings.keptThemeModes, [ThemeMode.dark]);

      await container
          .read(userProfileEditorProvider.notifier)
          .setTheme(ThemePreference.system);
      await Future<void>.delayed(Duration.zero);

      expect(settings.keptThemeModes, [ThemeMode.dark, ThemeMode.system]);
    });

    test('does not rewrite the theme the phone already keeps', () async {
      final settings = FakeDeviceSettings();
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          userRepositoryProvider.overrideWithValue(
            RecordingUserRepository(stored: _user(theme: ThemePreference.dark)),
          ),
          currentUidProvider.overrideWithValue('u'),
          deviceSettingsProvider.overrideWithValue(settings),
          rememberedThemeModeProvider.overrideWithValue(ThemeMode.dark),
        ],
      );
      container.listen(themeMemoryProvider, (_, _) {});
      await container.read(userProfileProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(settings.keptThemeModes, isEmpty);
    });

    test('keeps nothing without a profile', () async {
      final settings = FakeDeviceSettings();
      final container = makeMemory(RecordingUserRepository(), settings);
      await container.read(userProfileProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(settings.keptThemeModes, isEmpty);
    });

    test('a phone storage failure changes nothing', () async {
      final settings = FakeDeviceSettings(failure: Exception('keystore'));
      final container = makeMemory(
        RecordingUserRepository(stored: _user(theme: ThemePreference.dark)),
        settings,
      );
      await container.read(userProfileProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(settings.keptThemeModes, [ThemeMode.dark]);
      expect(container.read(themeProvider), ThemeMode.dark);
    });
  });
}

/// Profil émis par le test.
class _StreamedUserRepository extends FakeUserRepository {
  _StreamedUserRepository(this.profiles);

  final Stream<UserProfile?> profiles;

  @override
  Stream<UserProfile?> watchUser(String uid) => profiles;
}

/// Profil qui n'arrive pas : le chargement dure.
class _PendingUserRepository extends FakeUserRepository {
  @override
  Stream<UserProfile?> watchUser(String uid) => const Stream.empty();
}
