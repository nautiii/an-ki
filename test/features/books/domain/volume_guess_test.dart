import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/volume_guess.dart';
import 'package:flutter_test/flutter_test.dart';

BookMetadata record(
  String title, {
  String? subtitle,
  String? seriesTitle,
  int? seriesNumber,
}) => BookMetadata(
  title: title,
  subtitle: subtitle,
  authors: const [],
  seriesTitle: seriesTitle,
  seriesNumber: seriesNumber,
);

const medium = GuessConfidence.medium;
const low = GuessConfidence.low;
const high = GuessConfidence.high;

/// Un titre comme les catalogues le donnent, et ce qu'on en attend.
typedef Case = (String title, String name, int number, GuessConfidence level);

void expectGuesses(List<Case> cases) {
  for (final (title, name, number, level) in cases) {
    expect(
      guessVolume(record(title)),
      VolumeGuess(seriesName: name, number: number, confidence: level),
      reason: title,
    );
  }
}

void main() {
  group('structured BnF fields', () {
    test('series and number give a high confidence', () {
      expect(
        guessVolume(
          record('Droit devant !!', seriesTitle: 'One piece', seriesNumber: 15),
        ),
        const VolumeGuess(
          seriesName: 'One piece',
          number: 15,
          confidence: high,
        ),
      );
    });

    test('win over a contradicting title', () {
      expect(
        guessVolume(
          record('Blacksad T7', seriesTitle: 'Blacksad', seriesNumber: 6),
        ),
        const VolumeGuess(seriesName: 'Blacksad', number: 6, confidence: high),
      );
    });

    test('drop « édition originale » from the series name', () {
      expect(
        guessVolume(
          record(
            'Le Pays des Mers',
            seriesTitle: 'One Piece (édition originale)',
            seriesNumber: 3,
          ),
        ),
        const VolumeGuess(seriesName: 'One Piece', number: 3, confidence: high),
      );
    });

    test('keep the edition words of the series name', () {
      expect(
        guessVolume(
          record(
            'x',
            seriesTitle: 'Dragon ball perfect edition',
            seriesNumber: 2,
          ),
        )!.seriesName,
        'Dragon ball perfect edition',
      );
    });

    test('a series without a number looks for the number in the title', () {
      expect(
        guessVolume(
          record('Alors, tout tombe, tome 7', seriesTitle: 'Blacksad'),
        ),
        const VolumeGuess(
          seriesName: 'Blacksad',
          number: 7,
          confidence: medium,
        ),
      );
    });

    test('an unnumbered collection does not beat the series of the title', () {
      // Notice BnF réelle : le 225 « Shonen One Piece » n'a pas de numéro.
      expect(
        guessVolume(
          record(
            'One Piece - Édition originale - Tome 113',
            seriesTitle: 'Shonen One Piece',
          ),
        ),
        const VolumeGuess(
          seriesName: 'One Piece',
          number: 113,
          confidence: medium,
        ),
      );
      // Casse et tiret ignorés.
      expect(
        guessVolume(
          record('One Piece - Tome 113', seriesTitle: 'SHONEN ONE-PIECE'),
        )!.seriesName,
        'One Piece',
      );
    });

    test('a collection shorter than the title name stays the series', () {
      // Le texte avant le repère contient aussi le titre du tome.
      expect(
        guessVolume(
          record(
            'Astérix - Astérix chez les Belges - n° 24',
            seriesTitle: 'Astérix',
          ),
        )!.seriesName,
        'Astérix',
      );
      expect(
        guessVolume(
          record('Blacksad - Amarillo, tome 4', seriesTitle: 'Blacksad'),
        )!.seriesName,
        'Blacksad',
      );
      // Pas de rapprochement au milieu d'un mot.
      expect(
        guessVolume(record('Ange, tome 3', seriesTitle: 'Les Anges gardiens'))!
            .seriesName,
        'Les Anges gardiens',
      );
    });

    test('a series without a number and a title without one is not sure', () {
      expect(
        guessVolume(record('Un mois à Tokyo', seriesTitle: 'Short stories')),
        isNull,
      );
    });

    test('an out-of-range structured number falls back to the title', () {
      expect(
        guessVolume(
          record('One Piece T3', seriesTitle: 'One Piece', seriesNumber: 0),
        ),
        const VolumeGuess(
          seriesName: 'One Piece',
          number: 3,
          confidence: medium,
        ),
      );
      expect(
        guessVolume(
          record('One Piece', seriesTitle: 'One Piece', seriesNumber: 5000),
        ),
        isNull,
      );
    });
  });

  group('title with a marker', () {
    test('Glénat', () {
      expectGuesses(const [
        ('One Piece - Tome 108', 'One Piece', 108, medium),
        ('One piece T15', 'One piece', 15, medium),
        (
          'Dragon Ball - Perfect Edition - Tome 3',
          'Dragon Ball - Perfect Edition',
          3,
          medium,
        ),
        (
          'Dragon Ball Perfect Edition T.12',
          'Dragon Ball Perfect Edition',
          12,
          medium,
        ),
        (
          'Slam Dunk - Star Edition - Tome 4',
          'Slam Dunk - Star Edition',
          4,
          medium,
        ),
        ('Vagabond - Tome 37', 'Vagabond', 37, medium),
        ('Sakamoto Days T.2', 'Sakamoto Days', 2, medium),
      ]);
    });

    test('Kana', () {
      expectGuesses(const [
        ('Dr. Stone - Tome 12', 'Dr. Stone', 12, medium),
        ('Fire Force T.1', 'Fire Force', 1, medium),
        ('Death Note Black Edition T03', 'Death Note Black Edition', 3, medium),
        ('Naruto - Tome 72', 'Naruto', 72, medium),
        ('Hunter x Hunter Vol. 36', 'Hunter x Hunter', 36, medium),
      ]);
    });

    test('Pika', () {
      expectGuesses(const [
        ('Fairy Tail - Tome 63', 'Fairy Tail', 63, medium),
        (
          'Fruits Basket Perfect Edition Vol. 3',
          'Fruits Basket Perfect Edition',
          3,
          medium,
        ),
        ('Mortelle Adèle n° 4', 'Mortelle Adèle', 4, medium),
        ('Nana - Tome 21', 'Nana', 21, medium),
      ]);
    });

    test('Ki-oon', () {
      expectGuesses(const [
        ('Platinum End T.14', 'Platinum End', 14, medium),
        (
          "Les Carnets de l'apothicaire - Tome 9",
          "Les Carnets de l'apothicaire",
          9,
          medium,
        ),
        ('Tokyo Revengers Volume 3', 'Tokyo Revengers', 3, medium),
        ('Saga #12', 'Saga', 12, medium),
      ]);
    });

    test('Kurokawa', () {
      expectGuesses(const [
        ("L'Attaque des Titans - Tome 34", "L'Attaque des Titans", 34, medium),
        ('Pandora Hearts T.1', 'Pandora Hearts', 1, medium),
        ('Bleach - Colossale - Tome 2', 'Bleach - Colossale', 2, medium),
        (
          'Fullmetal Alchemist Deluxe T5',
          'Fullmetal Alchemist Deluxe',
          5,
          medium,
        ),
      ]);
    });

    test('Delcourt / Tonkam', () {
      expectGuesses(const [
        ('Berserk - Tome 41', 'Berserk', 41, medium),
        ('Tokyo Ghoul:re T7', 'Tokyo Ghoul:re', 7, medium),
        ('Gaston - Intégrale - Tome 2', 'Gaston - Intégrale', 2, medium),
        ('Lone Wolf & Cub - Tome 28', 'Lone Wolf & Cub', 28, medium),
        (
          'Berserk Deluxe Edition - Tome 7',
          'Berserk Deluxe Edition',
          7,
          medium,
        ),
      ]);
    });

    test('Dargaud', () {
      expectGuesses(const [
        (
          "Blake et Mortimer - Tome 1 - Le Secret de l'Espadon",
          'Blake et Mortimer',
          1,
          medium,
        ),
        ('Blacksad, tome 7 : Alors, tout tombe', 'Blacksad', 7, medium),
        ("Astérix - Tome 40 - L'Iris blanc", 'Astérix', 40, medium),
        ('Les Fées Valentines T2', 'Les Fées Valentines', 2, medium),
        ('Lucky Luke (Tome 12)', 'Lucky Luke', 12, medium),
      ]);
    });

    test('Dupuis', () {
      expectGuesses(const [
        (
          'Spirou et Fantasio - Tome 54 - Le Rayon noir',
          'Spirou et Fantasio',
          54,
          medium,
        ),
        ('Gaston, tome 18', 'Gaston', 18, medium),
        (
          'Les Schtroumpfs - Tome 41 : Le Schtroumpf financier',
          'Les Schtroumpfs',
          41,
          medium,
        ),
        ('Largo Winch - Tome 22', 'Largo Winch', 22, medium),
      ]);
    });

    test('every marker spelling', () {
      expectGuesses(const [
        ('Série tome 5', 'Série', 5, medium),
        ('Série Tome5', 'Série', 5, medium),
        ('Série T5', 'Série', 5, medium),
        ('Série T 5', 'Série', 5, medium),
        ('Série T.5', 'Série', 5, medium),
        ('Série T. 5', 'Série', 5, medium),
        ('Série Vol 5', 'Série', 5, medium),
        ('Série Vol. 5', 'Série', 5, medium),
        ('Série Volume 5', 'Série', 5, medium),
        ('Série #5', 'Série', 5, medium),
        ('Série # 5', 'Série', 5, medium),
        ('Série n°5', 'Série', 5, medium),
        ('Série N° 5', 'Série', 5, medium),
        ('Série nº 5', 'Série', 5, medium),
        ('Série No. 5', 'Série', 5, medium),
        ('Série numéro 5', 'Série', 5, medium),
        ('SÉRIE TOME 5', 'SÉRIE', 5, medium),
        ('Série, tome 5', 'Série', 5, medium),
        ('Série : tome 5', 'Série', 5, medium),
        ('Série (tome 5)', 'Série', 5, medium),
        ('Série - T05', 'Série', 5, medium),
      ]);
    });

    test('keeps a series name that contains digits', () {
      expectGuesses(const [
        ('20th Century Boys - Tome 3', '20th Century Boys', 3, medium),
        ('Blade Runner 2049 T2', 'Blade Runner 2049', 2, medium),
        ('Area 51 Tome 8', 'Area 51', 8, medium),
      ]);
    });
  });

  group('edition wording', () {
    test('« édition originale » is removed in every position', () {
      expectGuesses(const [
        ('One Piece - Édition originale - Tome 108', 'One Piece', 108, medium),
        ('One Piece (édition originale) T.5', 'One Piece', 5, medium),
        ('One Piece Édition originale Tome 6', 'One Piece', 6, medium),
        ('One Piece, édition originale, tome 7', 'One Piece', 7, medium),
        ('One Piece - Tome 8 (Édition originale)', 'One Piece', 8, medium),
        ('One Piece [édition originale] T9', 'One Piece', 9, medium),
        ('One Piece - EDITION ORIGINALE - Tome 10', 'One Piece', 10, medium),
      ]);
    });

    test(
      'Perfect Edition, Deluxe, Colossale and Intégrale stay in the name',
      () {
        expectGuesses(const [
          (
            'Dragon Ball Perfect Edition T1',
            'Dragon Ball Perfect Edition',
            1,
            medium,
          ),
          ('Berserk Deluxe T2', 'Berserk Deluxe', 2, medium),
          ('Naruto Colossale T3', 'Naruto Colossale', 3, medium),
          ('Gaston Intégrale T4', 'Gaston Intégrale', 4, medium),
          (
            'Dragon Ball - Perfect Edition (édition originale) - Tome 5',
            'Dragon Ball - Perfect Edition',
            5,
            medium,
          ),
        ]);
      },
    );
  });

  group('number first', () {
    test('« Tome 12 - One Piece » names the series after the number', () {
      expectGuesses(const [
        ('Tome 12 - One Piece', 'One Piece', 12, low),
        ('T5 - Naruto', 'Naruto', 5, low),
        ('Tome 3 : Fairy Tail - Le retour', 'Fairy Tail', 3, low),
      ]);
    });

    test('a bare marker has no series', () {
      expect(guessVolume(record('Tome 7')), isNull);
      expect(guessVolume(record('Tome 7 - ')), isNull);
    });
  });

  group('roman numerals', () {
    test('are read after tome, vol and T, with a low confidence', () {
      expectGuesses(const [
        ('Les Passagers du vent, tome II', 'Les Passagers du vent', 2, low),
        ('Les Cités obscures - T. IV', 'Les Cités obscures', 4, low),
        (
          'Les Maîtres de l\'orge - Volume III',
          "Les Maîtres de l'orge",
          3,
          low,
        ),
        (
          'La Quête de l\'oiseau du temps - Tome xii',
          "La Quête de l'oiseau du temps",
          12,
          low,
        ),
      ]);
    });

    test('are not read after # or n°', () {
      expect(guessVolume(record('Série #IV')), isNull);
      expect(guessVolume(record('Série n° IV')), isNull);
    });

    test('are not guessed without a marker', () {
      expect(guessVolume(record('Final Fantasy VII')), isNull);
      expect(guessVolume(record('Star Wars Épisode IV')), isNull);
      expect(guessVolume(record('Louis XIV')), isNull);
    });

    test('a word that only looks like a numeral is not one', () {
      expect(guessVolume(record('Tome civil')), isNull);
      expect(guessVolume(record('Série tome mix')), isNull);
    });
  });

  group('subtitle', () {
    test('a marker at the start of the subtitle numbers the title', () {
      expect(
        guessVolume(record('Les Fées Valentines', subtitle: 'Tome 2')),
        const VolumeGuess(
          seriesName: 'Les Fées Valentines',
          number: 2,
          confidence: medium,
        ),
      );
      expect(
        guessVolume(record('Fairy Tail', subtitle: "Vol. 5 : L'île de Galuna")),
        const VolumeGuess(
          seriesName: 'Fairy Tail',
          number: 5,
          confidence: medium,
        ),
      );
    });

    test('a bare number is the volume number', () {
      expect(
        guessVolume(record('Naruto', subtitle: '12')),
        const VolumeGuess(seriesName: 'Naruto', number: 12, confidence: medium),
      );
    });

    test('a roman numeral in the subtitle is not sure', () {
      expect(
        guessVolume(record('Thorgal', subtitle: 'Tome XII')),
        const VolumeGuess(seriesName: 'Thorgal', number: 12, confidence: low),
      );
    });

    test('the title wins over the subtitle', () {
      expect(
        guessVolume(record('Blacksad T7', subtitle: 'Tome 3')),
        const VolumeGuess(
          seriesName: 'Blacksad',
          number: 7,
          confidence: medium,
        ),
      );
    });

    test('a marker in the middle of the subtitle is not sure', () {
      expect(
        guessVolume(record('Naruto', subtitle: 'Le retour, tome 3')),
        isNull,
      );
    });

    test('a subtitle without a number gives nothing', () {
      expect(guessVolume(record('Naruto', subtitle: 'Le retour')), isNull);
      expect(guessVolume(record('Naruto', subtitle: '0')), isNull);
      expect(guessVolume(record('Naruto', subtitle: '1999')), isNull);
    });

    test('« édition originale » is removed from the subtitle', () {
      expect(
        guessVolume(record('Naruto', subtitle: 'Tome 4 (édition originale)')),
        const VolumeGuess(seriesName: 'Naruto', number: 4, confidence: medium),
      );
    });
  });

  group('a marker inside running text', () {
    test('followed by a word, the guess is only a low-confidence one', () {
      expectGuesses(const [
        ('Tintin - Vol 714 pour Sydney', 'Tintin', 714, low),
        ('Spirou n° 1 spécial', 'Spirou', 1, low),
        ('Série tome 5 hors commerce', 'Série', 5, low),
      ]);
    });

    test('an article alone before the marker is no series', () {
      for (final title in [
        "The No. 1 Ladies' Detective Agency",
        'Le Vol 93',
        "L'Vol 5",
        'Une T5',
      ]) {
        expect(guessVolume(record(title)), isNull, reason: title);
      }
    });

    test('a separator after the number keeps the medium confidence', () {
      expectGuesses(const [
        ('Série tome 5 : Le titre', 'Série', 5, medium),
        ('Série tome 5, Le titre', 'Série', 5, medium),
        ('Série tome 5 - Le titre', 'Série', 5, medium),
        ('Série (tome 5) Le titre', 'Série', 5, medium),
        ('Série tome 5.', 'Série', 5, medium),
      ]);
    });

    test('a lone T before letters is not a marker', () {
      for (final title in ['Accro à la TV', "Ain't I a Woman", 'Mister TV']) {
        expect(guessVolume(record(title)), isNull, reason: title);
      }
    });

    test('a long numeral is read', () {
      expectGuesses(const [
        ('Série - Tome XXXVIII', 'Série', 38, low),
        ('Série - Tome CCCXCIX', 'Série', 399, low),
      ]);
    });
  });

  group('not sure: null', () {
    test('several volumes followed by more words', () {
      for (final title in [
        'Naruto T1-T3 Édition collector',
        'Naruto - Tome 1 à 3 Les débuts',
        'Naruto - Tome 1 a 3 Les débuts',
        'Naruto - Tome 1-3 Les débuts',
        'Naruto - Tome 1 & 2 édition double',
        'Naruto - Tome 1 + 2 édition double',
        'Naruto - Tome 1 / 2 édition double',
        'Naruto - Tome 1 et 2 Les débuts',
      ]) {
        expect(guessVolume(record(title)), isNull, reason: title);
      }
    });

    test('very long input stays fast and gives nothing sure', () {
      final watch = Stopwatch()..start();
      for (final title in [
        '${' ' * 20000}x',
        'a${' - ' * 5000}b',
        'Tome ' * 3000,
      ]) {
        guessVolume(record(title));
      }

      expect(watch.elapsedMilliseconds, lessThan(2000));
    });

    test('no number at all', () {
      for (final title in [
        'One Piece',
        'Le Petit Prince',
        'Vol de nuit',
        "L'Attaque des Titans",
        '',
        '   ',
      ]) {
        expect(guessVolume(record(title)), isNull, reason: title);
      }
    });

    test('a number without a marker', () {
      for (final title in [
        'Fahrenheit 451',
        'Blade Runner 2049',
        '20th Century Boys',
        'One Piece 108',
        'Les 100 papillons',
        'Catch 22',
      ]) {
        expect(guessVolume(record(title)), isNull, reason: title);
      }
    });

    test('a box set or an out-of-series volume stays unclassified', () {
      for (final title in [
        'One Piece - Coffret Tome 1',
        'One Piece - Coffret',
        'Naruto - Coffret collector T1 à T3',
        'Hors-série n° 2',
        'Berserk - Hors série - Tome 1',
        'Astérix - Hors-série',
      ]) {
        expect(guessVolume(record(title)), isNull, reason: title);
      }
    });

    test('several volumes in one book', () {
      for (final title in [
        'One Piece - Tomes 1 à 3',
        'One Piece - Tome 1 à 3',
        'Naruto - Tome 1-3',
        'Naruto T1-T3',
        'Naruto - Tome 1 et 2',
        'Naruto - Tome 1 & 2',
        'Naruto - Volumes 1 et 2',
      ]) {
        expect(guessVolume(record(title)), isNull, reason: title);
      }
    });

    test(
      'a volume title that starts with a number after the number is fine',
      () {
        expectGuesses(const [
          ('Naruto - Tome 5 - 2 cœurs', 'Naruto', 5, medium),
          ('Naruto - Tome 5 - 3 ninjas', 'Naruto', 5, medium),
        ]);
      },
    );

    test('a decimal number', () {
      for (final title in [
        'Série - Tome 10.5',
        'Série - Tome 10,5',
        'Série T2.5',
      ]) {
        expect(guessVolume(record(title)), isNull, reason: title);
      }
    });

    test('a number out of range', () {
      for (final title in [
        'Série - Tome 0',
        'Série T2024',
        'Série - Tome 1001',
        'Série #0',
      ]) {
        expect(guessVolume(record(title)), isNull, reason: title);
      }
    });

    test('a marker stuck to a word', () {
      for (final title in ['Format12', 'Cet 5', 'Vol5mix', 'Tome5a']) {
        expect(guessVolume(record(title)), isNull, reason: title);
      }
    });
  });

  group('limits', () {
    test('the largest volume number is accepted', () {
      expect(
        guessVolume(record('Série T1000')),
        const VolumeGuess(
          seriesName: 'Série',
          number: 1000,
          confidence: medium,
        ),
      );
    });

    test(
      'a volume title that contains a marker is not mistaken for the series',
      () {
        expect(
          guessVolume(record('Série - Tome 3 - Vol. 4 du destin')),
          const VolumeGuess(seriesName: 'Série', number: 3, confidence: medium),
        );
      },
    );
  });

  group('VolumeGuess', () {
    test('compares by value', () {
      const a = VolumeGuess(seriesName: 'A', number: 1, confidence: medium);

      expect(
        a,
        const VolumeGuess(seriesName: 'A', number: 1, confidence: medium),
      );
      expect(
        a.hashCode,
        const VolumeGuess(
          seriesName: 'A',
          number: 1,
          confidence: medium,
        ).hashCode,
      );
      expect(
        a,
        isNot(const VolumeGuess(seriesName: 'A', number: 1, confidence: low)),
      );
      expect(
        a,
        isNot(
          const VolumeGuess(seriesName: 'B', number: 1, confidence: medium),
        ),
      );
      expect(
        a,
        isNot(
          const VolumeGuess(seriesName: 'A', number: 2, confidence: medium),
        ),
      );
    });
  });
}
