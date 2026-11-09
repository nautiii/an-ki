import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Profil de référence ; chaque argument en change un champ.
  UserProfile profile({
    String? pseudo = 'Q',
    String name = 'Quentin',
    String locale = 'fr',
  }) => UserProfile(
    id: '1',
    name: name,
    surname: 'Maillard',
    pseudo: pseudo,
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
    test('compares by value', () {
      final base = profile();
      final same = profile();

      expect(same, base);
      expect(same.hashCode, base.hashCode);
    });

    test('differs when a field differs', () {
      final base = profile();

      expect(profile(locale: 'en'), isNot(base));
    });

    test('compares the module choices by value, in any order', () {
      const a = UserProfile(
        id: '1',
        name: 'Q',
        surname: '',
        moduleChoices: {'books': true, 'gifts': false},
      );
      const b = UserProfile(
        id: '1',
        name: 'Q',
        surname: '',
        moduleChoices: {'gifts': false, 'books': true},
      );

      expect(b, a);
      expect(b.hashCode, a.hashCode);
      expect(
        const UserProfile(
          id: '1',
          name: 'Q',
          surname: '',
          moduleChoices: {'books': false, 'gifts': false},
        ),
        isNot(a),
      );
      expect(const UserProfile(id: '1', name: 'Q', surname: ''), isNot(a));
    });
  });
}
