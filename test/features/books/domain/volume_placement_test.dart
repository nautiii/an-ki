import 'package:an_ki/features/books/domain/book_metadata.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/volume_guess.dart';
import 'package:an_ki/features/books/domain/volume_placement.dart';
import 'package:flutter_test/flutter_test.dart';

Series _series(String id, String name, [List<String> keys = const []]) =>
    Series(id: id, name: name, keys: keys, complete: false);

VolumeGuess _guess(String name, GuessConfidence confidence) =>
    VolumeGuess(seriesName: name, number: 108, confidence: confidence);

void main() {
  group('placeVolume', () {
    test('joins the series that carries the key of its name', () {
      final onePiece = _series('s1', 'One Piece', ['one piece']);

      expect(
        placeVolume(_guess('ONE-PIECE', GuessConfidence.medium), [
          _series('s0', 'Naruto', ['naruto']),
          onePiece,
        ], newSeriesId: () => fail('no new series')),
        VolumePlacement(series: onePiece, isNew: false, number: 108),
      );
    });

    test('finds a series by an old name or, without keys, its name', () {
      final renamed = _series('s1', 'Piece One', ['one piece', 'piece one']);
      final keyless = _series('s2', 'Naruto');

      expect(
        placeVolume(_guess('One Piece', GuessConfidence.high), [
          renamed,
        ], newSeriesId: () => 'x')?.series,
        renamed,
      );
      expect(
        placeVolume(_guess('naruto', GuessConfidence.medium), [
          keyless,
        ], newSeriesId: () => 'x')?.series,
        keyless,
      );
    });

    test('creates a series named after the guess', () {
      expect(
        placeVolume(_guess('Blacksad', GuessConfidence.medium), [
          _series('s1', 'One Piece', ['one piece']),
        ], newSeriesId: () => 'new'),
        VolumePlacement(
          series: _series('new', 'Blacksad', ['blacksad']),
          isNew: true,
          number: 108,
        ),
      );
    });

    test('leaves a doubtful or missing guess unclassified', () {
      expect(
        placeVolume(
          _guess('One Piece', GuessConfidence.low),
          const [],
          newSeriesId: () => 'x',
        ),
        isNull,
      );
      expect(placeVolume(null, const [], newSeriesId: () => 'x'), isNull);
      expect(
        placeVolume(
          _guess('!!!', GuessConfidence.high),
          const [],
          newSeriesId: () => 'x',
        ),
        isNull,
      );
    });
  });

  test('keysOf adds the key of the name once', () {
    expect(keysOf(_series('s', 'One Piece', ['op'])), ['op', 'one piece']);
    expect(keysOf(_series('s', 'One Piece', ['one piece'])), ['one piece']);
  });

  test('volumeTitleOf keeps the subtitle after the title', () {
    expect(
      volumeTitleOf(
        const BookMetadata(
          title: 'Blacksad',
          subtitle: ' Alors, tout tombe ',
          authors: [],
        ),
      ),
      'Blacksad : Alors, tout tombe',
    );
    expect(
      volumeTitleOf(const BookMetadata(title: 'Dune', authors: [])),
      'Dune',
    );
    expect(
      volumeTitleOf(
        const BookMetadata(title: '', subtitle: 'Tome 2', authors: []),
      ),
      'Tome 2',
    );
  });
}
