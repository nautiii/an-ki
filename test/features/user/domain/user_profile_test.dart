import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Profil de référence ; chaque argument en change un champ.
  UserProfile profile({
    String? pseudo = 'Q',
    String name = 'Quentin',
    List<String> categories = const ['family'],
    String locale = 'fr',
  }) => UserProfile(
    id: '1',
    name: name,
    surname: 'Maillard',
    pseudo: pseudo,
    categories: categories,
    locale: locale,
    biometricToken: 'token',
  );

  group('greetingName', () {
    test('uses the pseudo when set', () {
      expect(profile().greetingName(guest: false), 'Q');
    });

    test('falls back to the first name without a pseudo', () {
      expect(profile(pseudo: null).greetingName(guest: false), 'Quentin');
      expect(profile(pseudo: ' ').greetingName(guest: false), 'Quentin');
    });

    test('is null without a pseudo nor a first name', () {
      expect(
        profile(pseudo: null, name: '').greetingName(guest: false),
        isNull,
      );
    });

    test('greets a guest by the pseudo only, never « Invité »', () {
      expect(profile().greetingName(guest: true), 'Q');
      // Profil d'invité écrit par les versions précédentes.
      expect(
        profile(pseudo: null, name: 'Invité').greetingName(guest: true),
        isNull,
      );
    });
  });

  group('equality', () {
    test('compares by value, categories included', () {
      final base = profile();
      // Liste distincte, de même contenu.
      final same = profile(categories: ['family']);

      expect(same, base);
      expect(same.hashCode, base.hashCode);
    });

    test('differs when a field differs', () {
      final base = profile();

      expect(profile(categories: ['friend']), isNot(base));
      expect(profile(locale: 'en'), isNot(base));
    });
  });
}
