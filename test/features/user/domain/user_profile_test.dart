import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = UserProfile(
    id: '1',
    name: 'Quentin',
    surname: 'Maillard',
    pseudo: 'Q',
    categories: ['family'],
    isDark: false,
    locale: 'fr',
    biometricToken: 'token',
  );

  group('displayName', () {
    test('uses the pseudo when set', () {
      expect(base.displayName, 'Q');
    });

    test('falls back to surname and name without a pseudo', () {
      expect(base.copyWith(clearPseudo: true).displayName, 'Maillard Quentin');
    });

    test('falls back to surname and name when the pseudo is empty', () {
      expect(base.copyWith(pseudo: '').displayName, 'Maillard Quentin');
    });
  });

  group('copyWith', () {
    test('overrides selected fields and keeps the rest', () {
      final copy = base.copyWith(pseudo: 'new', isDark: true, locale: 'en');

      expect(copy.pseudo, 'new');
      expect(copy.isDark, isTrue);
      expect(copy.locale, 'en');
      expect(copy.id, '1');
      expect(copy.name, 'Quentin');
      expect(copy.categories, ['family']);
      expect(copy.biometricToken, 'token');
    });

    test('keeps everything without arguments', () {
      expect(base.copyWith(), base);
    });

    test('clears the optional fields on request', () {
      final copy = base.copyWith(clearPseudo: true, clearBiometricToken: true);

      expect(copy.pseudo, isNull);
      expect(copy.biometricToken, isNull);
    });
  });

  group('equality', () {
    test('compares by value, categories included', () {
      final same = base.copyWith(categories: ['family']);

      expect(same, base);
      expect(same.hashCode, base.hashCode);
    });

    test('differs when a field differs', () {
      expect(base.copyWith(categories: ['friend']), isNot(base));
      expect(base.copyWith(locale: 'en'), isNot(base));
    });
  });
}
