import 'package:an_ki/features/books/domain/series_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('seriesKey', () {
    test('ignores case, accents and spacing', () {
      expect(seriesKey('  Astérix '), 'asterix');
      expect(seriesKey('ONE   PIECE'), 'one piece');
      expect(seriesKey('One piece'), seriesKey('One Piece'));
    });

    test('treats hyphens and punctuation as spaces', () {
      expect(seriesKey('One-Piece'), seriesKey('One Piece'));
      expect(
        seriesKey("L'Attaque des Titans"),
        seriesKey('l attaque des titans'),
      );
      expect(seriesKey('Dr. Stone'), 'dr stone');
      expect(seriesKey('Tokyo Ghoul:re'), 'tokyo ghoul re');
      expect(seriesKey('Lone Wolf & Cub'), 'lone wolf cub');
      expect(seriesKey('Soul Eater Not!'), 'soul eater not');
    });

    test('reads a decomposed accent like the precomposed letter', () {
      expect(seriesKey('Pokémon'), 'pokemon');
      expect(seriesKey('Pokémon'), 'pokemon');
      expect(seriesKey('Pokémon'), seriesKey('Pokémon'));
    });

    test('keeps digits', () {
      expect(seriesKey('20th Century Boys'), '20th century boys');
    });

    test('keeps edition words: they are other series', () {
      expect(
        seriesKey('Dragon Ball Perfect Edition'),
        isNot(seriesKey('Dragon Ball')),
      );
      expect(seriesKey('Berserk Deluxe'), isNot(seriesKey('Berserk')));
      expect(seriesKey('Gaston - Intégrale'), 'gaston integrale');
    });

    test('is empty for a name without letters or digits', () {
      expect(seriesKey(''), '');
      expect(seriesKey(' - '), '');
    });

    test('is idempotent', () {
      final key = seriesKey("L'Attaque des Titans — Édition");
      expect(seriesKey(key), key);
    });
  });
}
