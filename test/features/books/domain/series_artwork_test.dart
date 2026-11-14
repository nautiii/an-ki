import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/series_artwork.dart';
import 'package:an_ki/features/books/domain/series_key.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 14);

Series _series(String name, {SeriesArtwork? artwork, List<String>? keys}) =>
    Series(
      id: name,
      name: name,
      keys: keys ?? [seriesKey(name)],
      complete: false,
      artwork: artwork,
    );

SeriesArtwork _artwork(String forName, String? url, {DateTime? checkedAt}) =>
    SeriesArtwork(url: url, forName: forName, checkedAt: checkedAt ?? _now);

ArtworkCandidate _candidate(List<String> titles, [String? url = 'https://a']) =>
    ArtworkCandidate(titles: titles, imageUrl: url);

void main() {
  group('artworkUrlOf', () {
    test('is the url found for the current name', () {
      expect(
        artworkUrlOf(
          _series('One Piece', artwork: _artwork('One Piece', 'https://a')),
        ),
        'https://a',
      );
    });

    test('is null before any lookup, after a rename, or when empty', () {
      expect(artworkUrlOf(_series('One Piece')), isNull);
      expect(
        artworkUrlOf(
          _series('One Piece', artwork: _artwork('Old', 'https://a')),
        ),
        isNull,
      );
      expect(
        artworkUrlOf(_series('One Piece', artwork: _artwork('One Piece', ''))),
        isNull,
      );
    });
  });

  group('needsArtworkLookup', () {
    test('a series never looked up is due', () {
      expect(needsArtworkLookup(_series('One Piece'), _now), isTrue);
    });

    test('a found artwork is never asked again', () {
      final series = _series(
        'One Piece',
        artwork: _artwork('One Piece', 'https://a', checkedAt: DateTime(2020)),
      );

      expect(needsArtworkLookup(series, _now), isFalse);
    });

    test('a rename asks again', () {
      final series = _series(
        'One Piece',
        artwork: _artwork('One Pièce', 'https://a'),
      );

      expect(needsArtworkLookup(series, _now), isTrue);
    });

    test('nothing found is asked again after the retry interval', () {
      SeriesArtwork missing(Duration age) =>
          _artwork('Blacksad', null, checkedAt: _now.subtract(age));

      expect(
        needsArtworkLookup(
          _series('Blacksad', artwork: missing(const Duration(days: 29))),
          _now,
        ),
        isFalse,
      );
      expect(
        needsArtworkLookup(
          _series('Blacksad', artwork: missing(artworkRetryInterval)),
          _now,
        ),
        isTrue,
      );
    });

    test('a name without letters or digits is never looked up', () {
      expect(needsArtworkLookup(_series(' ?! '), _now), isFalse);
    });
  });

  test('seriesToIllustrate keeps the due series in order, up to the limit', () {
    final due = [for (var i = 0; i < 5; i++) _series('S$i')];
    final done = _series('Done', artwork: _artwork('Done', 'https://a'));

    expect(seriesToIllustrate([due[0], done, ...due.skip(1)], _now, limit: 3), [
      due[0],
      due[1],
      due[2],
    ]);
  });

  group('matchArtwork', () {
    test('takes the first candidate whose title has the series key', () {
      final url = matchArtwork(_series('One Piece'), [
        _candidate(['One Piece Party'], 'https://party'),
        _candidate(['ONE PIECE', 'One Piece'], 'https://op'),
      ]);

      expect(url, 'https://op');
    });

    test('a synonym matches (a French title)', () {
      final url = matchArtwork(_series("L'Attaque des Titans"), [
        _candidate([
          'Shingeki no Kyojin',
          'Attack on Titan',
          "L'Attaque des Titans",
        ]),
      ]);

      expect(url, 'https://a');
    });

    test('a former name of the series matches', () {
      final series = _series(
        'Les Titans',
        keys: [seriesKey('Les Titans'), seriesKey('Shingeki no Kyojin')],
      );

      expect(
        matchArtwork(series, [
          _candidate(['Shingeki no Kyojin']),
        ]),
        'https://a',
      );
    });

    test('the × of a Japanese title matches an x', () {
      expect(
        matchArtwork(_series('Spy x Family'), [
          _candidate(['SPY×FAMILY']),
        ]),
        'https://a',
      );
    });

    test('a final X is part of the name', () {
      expect(
        matchArtwork(_series('Malcolm'), [
          _candidate(['Malcolm X']),
        ]),
        isNull,
      );
    });

    test('another work, or a candidate without image, gives nothing', () {
      expect(
        matchArtwork(_series('Dragon Ball'), [
          _candidate(['Dragon Ball Super']),
          _candidate(['Dragon Ball'], null),
          _candidate(['Dragon Ball'], ''),
        ]),
        isNull,
      );
      expect(matchArtwork(_series('Tintin'), const []), isNull);
    });
  });

  test('candidates compare by value', () {
    expect(_candidate(['A']), _candidate(['A']));
    expect(_candidate(['A']).hashCode, _candidate(['A']).hashCode);
    expect(_candidate(['A']), isNot(_candidate(['B'])));
  });
}
