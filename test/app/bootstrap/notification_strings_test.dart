import 'package:an_ki/app/bootstrap/notification_strings.dart';
import 'package:an_ki/core/providers/device_locales_provider.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer containerIn(
    String? locale, {
    List<Locale> device = const [Locale('fr', 'FR')],
  }) => ProviderContainer.test(
    overrides: [
      localizedNotificationStrings,
      deviceLocalesProvider.overrideWithValue(device),
      userProfileProvider.overrideWithValue(
        AsyncData(
          locale == null
              ? null
              : UserProfile(id: 'u1', name: '', surname: '', locale: locale),
        ),
      ),
    ],
  );

  String wishAction(ProviderContainer container) =>
      container.read(notificationStringsProvider).wishAction;

  test('words the reminders in the language of the profile', () {
    expect(wishAction(containerIn('en')), 'Send wishes');
    expect(
      wishAction(containerIn('fr', device: const [Locale('en')])),
      'Souhaiter',
    );
  });

  test('follows the phone without a profile', () {
    expect(wishAction(containerIn(null)), 'Souhaiter');
    expect(
      wishAction(containerIn(null, device: const [Locale('en')])),
      'Send wishes',
    );
  });

  test('falls back to English without a translated language', () {
    expect(
      wishAction(containerIn('de', device: const [Locale('de')])),
      'Send wishes',
    );
  });
}
