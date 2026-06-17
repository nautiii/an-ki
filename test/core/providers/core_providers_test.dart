import 'package:an_ki/core/providers/locale_provider.dart';
import 'package:an_ki/core/providers/navigation_provider.dart';
import 'package:an_ki/core/theme/providers/theme_provider.dart';
import 'package:an_ki/features/birthday/providers/home_view_provider.dart';
import 'package:an_ki/features/user/data/models/user_model.dart';
import 'package:an_ki/features/user/data/repositories/user_repository.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';

class StubUserRepository extends FakeUserRepository {
  StubUserRepository(this._stored);
  UserModel? _stored;

  @override
  Future<UserModel?> fetchUser(String uid) async => _stored;

  @override
  Future<void> updateUser(UserModel user) async => _stored = user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NavigationNotifier', () {
    test('defaults to the birthdays tab and switches tab', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(navigationProvider), MainTab.birthdays);
      container.read(navigationProvider.notifier).setTab(MainTab.scanner);
      expect(container.read(navigationProvider), MainTab.scanner);
    });
  });

  group('HomeViewNotifier', () {
    test('toggles between list and calendar', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(homeViewProvider), HomeViewType.list);
      container.read(homeViewProvider.notifier).toggle();
      expect(container.read(homeViewProvider), HomeViewType.calendar);
      container.read(homeViewProvider.notifier).toggle();
      expect(container.read(homeViewProvider), HomeViewType.list);
    });
  });

  ProviderContainer userContainer(UserModel? stored) {
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(StubUserRepository(stored)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  UserModel user({bool isDark = false, String locale = 'fr'}) => UserModel(
    id: 'u',
    name: 'A',
    surname: 'B',
    isDark: isDark,
    locale: locale,
  );

  group('LocaleNotifier', () {
    test('defaults to French when no user is loaded', () {
      final container = userContainer(null);
      expect(container.read(localeProvider), const Locale('fr'));
    });

    test('reflects the loaded user locale', () async {
      final container = userContainer(user(locale: 'en'));
      container.read(localeProvider); // keep alive to register the listener

      await container.read(userProvider.notifier).loadUser('u');

      expect(container.read(localeProvider), const Locale('en'));
    });

    test('setLocale updates the state and persists it on the user', () async {
      final container = userContainer(user());
      await container.read(userProvider.notifier).loadUser('u');

      container.read(localeProvider.notifier).setLocale(const Locale('en'));
      await Future<void>.delayed(Duration.zero); // let updateLocale settle

      expect(container.read(localeProvider), const Locale('en'));
      expect(container.read(userProvider).user?.locale, 'en');
    });
  });

  group('ThemeNotifier', () {
    test('uses the platform brightness when no user is loaded', () {
      final container = userContainer(null);
      // The test platform reports light brightness by default.
      expect(container.read(themeProvider), ThemeMode.light);
      expect(container.read(themeProvider.notifier).isDark, false);
    });

    test('reflects the loaded user theme', () async {
      final container = userContainer(user(isDark: true));
      container.read(themeProvider); // keep alive

      await container.read(userProvider.notifier).loadUser('u');

      expect(container.read(themeProvider), ThemeMode.dark);
    });

    test('toggle flips the mode and persists it on the user', () async {
      final container = userContainer(user());
      await container.read(userProvider.notifier).loadUser('u');
      expect(container.read(themeProvider), ThemeMode.light);

      container.read(themeProvider.notifier).toggle();
      await Future<void>.delayed(Duration.zero); // let updateTheme settle

      expect(container.read(themeProvider), ThemeMode.dark);
      expect(container.read(userProvider).user?.isDark, true);
    });
  });
}
