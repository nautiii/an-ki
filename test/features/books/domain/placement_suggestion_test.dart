import 'package:an_ki/features/books/domain/placement_suggestion.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:flutter_test/flutter_test.dart';

Series series(String id, String name, [List<String> keys = const []]) =>
    Series(id: id, name: name, keys: keys, complete: false);

Volume volume(String title, {String? seriesId, int? number}) => Volume(
  id: title,
  seriesId: seriesId,
  number: number,
  title: title,
  authors: const [],
  lookup: LookupState.found,
  addedAt: DateTime(2026),
);

/// Étagère des [owned] numéros de chaque série.
List<ShelfEntry> entries(Map<Series, List<int>> owned) =>
    shelfOf(owned.keys.toList(), [
      for (final MapEntry(key: s, value: numbers) in owned.entries)
        for (final n in numbers) volume('${s.id}$n', seriesId: s.id, number: n),
    ]).entries;

void main() {
  final spy = series('spy', 'Spy x Family', ['spy x family']);
  final prince = series('pp', 'Le Petit Prince', ['le petit prince']);

  group('suggestPlacement', () {
    test('joins the series of the guessed name, at the guessed number', () {
      expect(
        suggestPlacement(
          volume('SPY x FAMILY - Tome 13'),
          entries({
            spy: [1, 2],
          }),
        ),
        PlacementSuggestion(
          series: spy,
          seriesName: 'Spy x Family',
          number: 13,
        ),
      );
    });

    group('alreadyOwned', () {
      Volume scanned(String isbn, String title, {String? seriesId}) => Volume(
        id: isbn,
        isbn: isbn,
        seriesId: seriesId,
        number: seriesId == null ? null : 2,
        title: title,
        authors: const [],
        lookup: LookupState.found,
        addedAt: DateTime(2026),
      );

      test('a scanned copy of that number: a second edition', () {
        final shelf = shelfOf(
          [spy],
          [scanned('9782505075000', 'Spy 2', seriesId: 'spy')],
        ).entries;

        final suggestion = suggestPlacement(
          scanned('9782505075017', 'SPY x FAMILY - Tome 2'),
          shelf,
        );

        expect((suggestion?.number, suggestion?.alreadyOwned), (2, true));
      });

      test('a copy added by hand is replaced by a scanned volume', () {
        // `entries` ajoute des tomes à la main (leur id n'est pas un ISBN).
        final shelf = entries({
          spy: [1, 2],
        });

        expect(
          suggestPlacement(
            scanned('9782505075017', 'SPY x FAMILY - Tome 2'),
            shelf,
          )?.alreadyOwned,
          isFalse,
        );
        expect(
          suggestPlacement(
            volume('SPY x FAMILY - Tome 2'),
            shelf,
          )?.alreadyOwned,
          isTrue,
        );
      });

      test('a number the series lacks is free', () {
        expect(
          suggestPlacement(
            volume('SPY x FAMILY - Tome 13'),
            entries({
              spy: [1, 2],
            }),
          )?.alreadyOwned,
          isFalse,
        );
      });
    });

    test('offers even a doubtful guess (roman numeral)', () {
      final suggestion = suggestPlacement(
        volume('Blacksad tome VII'),
        entries({
          spy: [1],
        }),
      );

      expect(
        suggestion,
        const PlacementSuggestion(seriesName: 'Blacksad', number: 7),
      );
      expect(suggestion!.isNew, isTrue);
    });

    test('a new series is named after the guess', () {
      expect(
        suggestPlacement(volume('One Piece - Tome 108'), const []),
        const PlacementSuggestion(seriesName: 'One Piece', number: 108),
      );
    });

    test('without a number, the title names a new series of volume 1', () {
      expect(
        suggestPlacement(
          volume('Le Petit Prince : édition illustrée'),
          const [],
        ),
        const PlacementSuggestion(seriesName: 'Le Petit Prince', number: 1),
      );
    });

    test('without a number, a series of that name gets its next volume', () {
      expect(
        suggestPlacement(
          volume('Le petit prince'),
          entries({
            prince: [1, 3],
          }),
        ),
        PlacementSuggestion(
          series: prince,
          seriesName: 'Le Petit Prince',
          number: 2,
        ),
      );

      const complete = Series(
        id: 'pp',
        name: 'Le Petit Prince',
        keys: ['le petit prince'],
        complete: true,
      );
      expect(
        suggestPlacement(
          volume('Le Petit Prince'),
          entries({
            complete: [1],
          }),
        )?.number,
        2,
      );
    });

    test('finds a series by an old name', () {
      final renamed = series('op', 'Piece One', ['one piece', 'piece one']);

      expect(
        suggestPlacement(
          volume('One Piece - Tome 7'),
          entries({
            renamed: [1],
          }),
        ),
        PlacementSuggestion(
          series: renamed,
          seriesName: 'Piece One',
          number: 7,
        ),
      );
    });

    test('nothing for a box set, a special or a half volume', () {
      final onePiece = series('op', 'One Piece', ['one piece']);
      for (final title in [
        'One Piece - Tome 10.5',
        'One Piece - Coffret',
        'One Piece - Hors-série',
        'One Piece - Tomes 1 à 3',
      ]) {
        expect(
          suggestPlacement(
            volume(title),
            entries({
              onePiece: [1],
            }),
          ),
          isNull,
          reason: title,
        );
      }
    });

    test('nothing for a volume without a title', () {
      expect(
        suggestPlacement(
          volume('  '),
          entries({
            spy: [1],
          }),
        ),
        isNull,
      );
      expect(suggestPlacement(volume(''), const []), isNull);
    });
  });
}
