import 'package:an_ki/features/user/domain/display_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('namesFromDisplayName', () {
    test('takes the first word as the name and the rest as the surname', () {
      expect(namesFromDisplayName('Camille Martin'), (
        name: 'Camille',
        surname: 'Martin',
      ));
      expect(namesFromDisplayName('Jean Pierre Dupont'), (
        name: 'Jean',
        surname: 'Pierre Dupont',
      ));
    });

    test('a single word is a name without surname', () {
      expect(namesFromDisplayName('Mamie'), (name: 'Mamie', surname: ''));
    });

    test('ignores stray spaces', () {
      expect(namesFromDisplayName('  Camille   Martin '), (
        name: 'Camille',
        surname: 'Martin',
      ));
    });

    test('an empty display name gives the fallback', () {
      expect(namesFromDisplayName(''), (name: '', surname: ''));
      expect(namesFromDisplayName('  ', fallback: '-'), (
        name: '-',
        surname: '',
      ));
    });
  });
}
