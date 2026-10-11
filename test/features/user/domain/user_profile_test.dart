import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Profil de référence ; chaque argument en change un champ.
  UserProfile profile({
    String? pseudo = 'Q',
    List<String> categories = const ['family'],
    String locale = 'fr',
  }) => UserProfile(
    id: '1',
    name: 'Quentin',
    surname: 'Maillard',
    pseudo: pseudo,
    categories: categories,
    isDark: false,
    locale: locale,
    biometricToken: 'token',
  );

  group('displayName', () {
    test('uses the pseudo when set', () {
      expect(profile().displayName, 'Q');
    });

    test('falls back to surname and name without a pseudo', () {
      expect(profile(pseudo: null).displayName, 'Maillard Quentin');
    });

    test('falls back to surname and name when the pseudo is empty', () {
      expect(profile(pseudo: '').displayName, 'Maillard Quentin');
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
