import 'package:an_ki/features/birthday/domain/stable_hash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Les teintes des anciens groupes et la variante des vœux en dépendent :
  // ces valeurs ne doivent jamais changer.
  test('matches the FNV-1a 32-bit reference vectors', () {
    expect(stableHash(''), 0x811c9dc5);
    expect(stableHash('a'), 0xe40c292c);
    expect(stableHash('foobar'), 0xbf9cf968);
  });

  test('stays a 32-bit unsigned value for any text', () {
    for (final text in ['é', 'Zoé/2026', '🎂']) {
      expect(stableHash(text), inInclusiveRange(0, 0xffffffff));
    }
  });
}
