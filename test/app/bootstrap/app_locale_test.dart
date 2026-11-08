import 'package:an_ki/app/bootstrap/app_locale.dart';
import 'package:an_ki/core/providers/device_locales_provider.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveAppLocale', () {
    Locale resolve(List<Locale> device, {Locale? chosen}) =>
        resolveAppLocale(chosen: chosen, device: device);

    test('takes the language of the phone, without its region', () {
      expect(resolve(const [Locale('fr', 'FR')]), const Locale('fr'));
      expect(resolve(const [Locale('fr', 'CA')]), const Locale('fr'));
      expect(resolve(const [Locale('en', 'GB')]), const Locale('en'));
    });

    test('takes the first translated language of the phone, in order', () {
      expect(
        resolve(const [Locale('de', 'DE'), Locale('fr', 'FR'), Locale('en')]),
        const Locale('fr'),
      );
    });

    test('falls back to English', () {
      expect(resolve(const [Locale('de', 'DE')]), const Locale('en'));
      expect(resolve(const []), const Locale('en'));
    });

    test('puts the language chosen in the profile first', () {
      expect(
        resolve(const [Locale('fr', 'FR')], chosen: const Locale('en')),
        const Locale('en'),
      );
      // Choix sans traduction : la langue du téléphone.
      expect(
        resolve(const [Locale('fr', 'FR')], chosen: const Locale('de')),
        const Locale('fr'),
      );
    });
  });

  group('appLocaleProvider', () {
    ProviderContainer containerWith({
      required List<Locale> device,
      UserProfile? profile,
    }) => ProviderContainer.test(
      overrides: [
        deviceLocalesProvider.overrideWithValue(device),
        userProfileProvider.overrideWithValue(AsyncData(profile)),
      ],
    );

    test('follows the phone without a profile or a choice', () {
      expect(
        containerWith(device: const [Locale('en', 'US')])
            .read(appLocaleProvider),
        const Locale('en'),
      );
      expect(
        containerWith(
          device: const [Locale('fr', 'FR')],
          profile: const UserProfile(id: 'u', name: '', surname: ''),
        ).read(appLocaleProvider),
        const Locale('fr'),
      );
    });

    test('keeps the language chosen in the profile', () {
      expect(
        containerWith(
          device: const [Locale('en', 'US')],
          profile: const UserProfile(
            id: 'u',
            name: '',
            surname: '',
            locale: 'fr',
          ),
        ).read(appLocaleProvider),
        const Locale('fr'),
      );
    });
  });
}
