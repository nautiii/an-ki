import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf_takeover.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:flutter_test/flutter_test.dart';

Series _series(String id, String name, List<String> keys) =>
    Series(id: id, name: name, keys: keys, complete: false);

Volume _volume(String id, {String? seriesId, int? number, String? isbn}) =>
    Volume(
      id: id,
      seriesId: seriesId,
      number: number,
      isbn: isbn ?? id,
      title: 'T',
      authors: const [],
      lookup: LookupState.found,
      addedAt: DateTime(2026, 11, 8),
    );

void main() {
  test('a series with a shared key joins the target one', () {
    final marked = MarkedShelf(
      guestUid: 'guest',
      series: [
        _series('g1', 'One-Piece', ['one piece', 'op']),
        _series('g2', 'Naruto', ['naruto']),
      ],
      volumes: [
        _volume('a', seriesId: 'g1', number: 3),
        _volume('b', seriesId: 'g2', number: 1),
        _volume('c'),
      ],
      legacyBookIds: const ['k1'],
    );

    final plan = planShelfTakeOver(
      marked,
      targetSeries: [
        _series('t1', 'One Piece', ['one piece']),
      ],
      targetVolumes: const [],
    );

    expect(
      plan,
      ShelfTakeOverPlan(
        guestUid: 'guest',
        seriesToCopy: [
          _series('g2', 'Naruto', ['naruto']),
        ],
        keysToAdd: const {
          't1': ['op'],
        },
        volumesToCopy: [
          _volume('a', seriesId: 't1', number: 3),
          _volume('b', seriesId: 'g2', number: 1),
          _volume('c'),
        ],
        guestSeriesIds: const ['g1', 'g2'],
        guestVolumeIds: const ['a', 'b', 'c'],
        legacyBookIds: const ['k1'],
      ),
    );
  });

  test('two guest series joining one target add each key once', () {
    final plan = planShelfTakeOver(
      MarkedShelf(
        guestUid: 'guest',
        series: [
          _series('g1', 'One Piece', ['one piece', 'op']),
          _series('g2', 'OP', ['op', 'one piece']),
        ],
        volumes: const [],
        legacyBookIds: const [],
      ),
      targetSeries: [
        _series('t1', 'One Piece', ['one piece']),
      ],
      targetVolumes: const [],
    );

    expect(plan.keysToAdd, {
      't1': ['op'],
    });
    expect(plan.seriesToCopy, isEmpty);
  });

  test('a volume the target already owns is skipped', () {
    final plan = planShelfTakeOver(
      MarkedShelf(
        guestUid: 'guest',
        series: const [],
        volumes: [
          _volume('9782344059568'),
          _volume('manual', isbn: '9782505000002'),
          _volume('new'),
        ],
        legacyBookIds: const [],
      ),
      targetSeries: const [],
      targetVolumes: [
        _volume('9782344059568', seriesId: 't1', number: 108),
        _volume('9782505000002'),
      ],
    );

    expect(plan.volumesToCopy, [_volume('new')]);
    expect(plan.guestVolumeIds, ['9782344059568', 'manual', 'new']);
  });

  test('an empty guest shelf gives an empty plan', () {
    const marked = MarkedShelf(
      guestUid: 'guest',
      series: [],
      volumes: [],
      legacyBookIds: [],
    );

    expect(marked.isEmpty, isTrue);
    expect(
      planShelfTakeOver(
        marked,
        targetSeries: const [],
        targetVolumes: const [],
      ),
      const ShelfTakeOverPlan(
        guestUid: 'guest',
        seriesToCopy: [],
        keysToAdd: {},
        volumesToCopy: [],
        guestSeriesIds: [],
        guestVolumeIds: [],
        legacyBookIds: [],
      ),
    );
  });
}
