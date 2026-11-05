import 'package:an_ki/app/bootstrap/notification_strings.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer containerIn(String? locale) => ProviderContainer.test(
    overrides: [
      localizedNotificationStrings,
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
    expect(wishAction(containerIn('fr')), 'Souhaiter');
  });

  test('falls back to French without a profile', () {
    expect(wishAction(containerIn(null)), 'Souhaiter');
  });

  test('resolves an untranslated language like MaterialApp', () {
    // Sans traduction : la première langue prise en charge, l'anglais.
    expect(wishAction(containerIn('de')), 'Send wishes');
  });
}
