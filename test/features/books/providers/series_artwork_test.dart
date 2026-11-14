import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/anilist_catalog.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/book_failure.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/series_artwork.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/providers/series_artwork.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

final _now = DateTime(2026, 11, 14, 9);

Series _series(String id, String name, {SeriesArtwork? artwork}) => Series(
  id: id,
  name: name,
  keys: [name.toLowerCase()],
  complete: false,
  artwork: artwork,
);

const _onePiece = ArtworkCandidate(
  titles: ['ONE PIECE', 'One Piece'],
  imageUrl: 'https://a/op.jpg',
);

void main() {
  late RecordingBookshelfRepository shelf;
  late RecordingAniListCatalog aniList;

  ProviderContainer makeContainer({String? uid = 'u1', Override? session}) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(shelf),
        aniListCatalogProvider.overrideWithValue(aniList),
        session ?? currentUidProvider.overrideWithValue(uid),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    container.listen(seriesArtworkLookupProvider, (_, _) {});
    return container;
  }

  SeriesArtworkLookup lookupOf(ProviderContainer container) =>
      container.read(seriesArtworkLookupProvider.notifier);

  /// Laisse partir les écritures non attendues.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  SeriesArtwork? artworkOf(String id) =>
      shelf.series.singleWhere((s) => s.id == id).artwork;

  setUp(() {
    shelf = RecordingBookshelfRepository(
      series: [_series('op', 'One Piece'), _series('bs', 'Blacksad')],
    );
    aniList = RecordingAniListCatalog({
      'One Piece': [_onePiece],
    });
  });

  test('stores the matching artwork, or the miss, for each series', () async {
    final container = makeContainer();

    await lookupOf(container).illustrateMissing();
    await flush();

    expect(aniList.asked, ['One Piece', 'Blacksad']);
    expect(
      artworkOf('op'),
      SeriesArtwork(
        url: 'https://a/op.jpg',
        forName: 'One Piece',
        checkedAt: _now,
      ),
    );
    expect(
      artworkOf('bs'),
      SeriesArtwork(forName: 'Blacksad', checkedAt: _now),
    );
  });

  test('a series already illustrated is not asked again', () async {
    shelf = RecordingBookshelfRepository(
      series: [
        _series(
          'op',
          'One Piece',
          artwork: SeriesArtwork(
            url: 'https://a/op.jpg',
            forName: 'One Piece',
            checkedAt: DateTime(2026),
          ),
        ),
      ],
    );
    final container = makeContainer();

    await lookupOf(container).illustrateMissing();

    expect(aniList.asked, isEmpty);
  });

  test('a second pass in the session asks nothing again', () async {
    // Écriture refusée : la série reste sans image, mais n'est pas redemandée.
    shelf = RecordingBookshelfRepository(
      series: [_series('op', 'One Piece'), _series('bs', 'Blacksad')],
      failure: ShelfFailure.denied,
    );
    final container = makeContainer();

    await lookupOf(container).illustrateMissing();
    await flush();
    await lookupOf(container).illustrateMissing();

    expect(aniList.asked, ['One Piece', 'Blacksad']);
  });

  test('the first catalog failure stops the pass', () async {
    aniList.failure = BookFailure.network;
    final container = makeContainer();

    await lookupOf(container).illustrateMissing();
    await flush();

    expect(aniList.asked, ['One Piece']);
    expect(artworkOf('op'), isNull);

    // Hors ligne, rien n'est marqué : la passe suivante la redemande.
    aniList.failure = null;
    await lookupOf(container).illustrateMissing();
    expect(aniList.asked, ['One Piece', 'One Piece', 'Blacksad']);
  });

  test('only one pass runs at a time', () async {
    final gate = Completer<void>();
    aniList.gate = gate.future;
    final container = makeContainer();

    final first = lookupOf(container).illustrateMissing();
    await lookupOf(container).illustrateMissing();
    gate.complete();
    await first;

    expect(aniList.asked, ['One Piece', 'Blacksad']);
  });

  test('a series renamed during the lookup is not written', () async {
    final gate = Completer<void>();
    aniList.gate = gate.future;
    shelf = RecordingBookshelfRepository(series: [_series('op', 'One Piece')]);
    final container = makeContainer();

    final pass = lookupOf(container).illustrateMissing();
    await flush();
    await shelf.renameSeries('u1', 'op', name: 'One Pièce', key: 'one piece');
    await flush();
    gate.complete();
    await pass;
    await flush();

    expect(artworkOf('op'), isNull);

    // Le nouveau nom est cherché à la passe suivante.
    await lookupOf(container).illustrateMissing();
    expect(aniList.asked, ['One Piece', 'One Pièce']);
  });

  test(
    'a series renamed after a pass is asked again by its new name',
    () async {
      final container = makeContainer();
      await lookupOf(container).illustrateMissing();
      await flush();

      await shelf.renameSeries(
        'u1',
        'bs',
        name: 'Blacksad 2',
        key: 'blacksad 2',
      );
      await flush();
      await lookupOf(container).illustrateMissing();

      expect(aniList.asked, ['One Piece', 'Blacksad', 'Blacksad 2']);
    },
  );

  test('another account signed in meanwhile: nothing written', () async {
    final gate = Completer<void>();
    aniList.gate = gate.future;
    final container = makeContainer(
      session: currentUidProvider.overrideWith(
        (ref) => ref.watch(_uidProvider),
      ),
    );

    final pass = lookupOf(container).illustrateMissing();
    await flush();
    expect(aniList.asked, ['One Piece']);
    container.read(_uidProvider.notifier).set('u2');
    gate.complete();
    await pass;
    await flush();

    expect(aniList.asked, ['One Piece']);
    expect(shelf.series.map((s) => s.artwork), [isNull, isNull]);
  });

  test('signed out, nothing is asked', () async {
    final container = makeContainer(uid: null);

    await lookupOf(container).illustrateMissing();

    expect(aniList.asked, isEmpty);
  });
}

class _Uid extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void set(String? uid) => state = uid;
}

final _uidProvider = NotifierProvider<_Uid, String?>(_Uid.new);
