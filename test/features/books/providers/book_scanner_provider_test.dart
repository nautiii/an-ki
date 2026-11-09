import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/book_scanner_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

Volume _volume(String id, {String? seriesId, int? number, required int day}) =>
    Volume(
      id: id,
      seriesId: seriesId,
      number: number,
      title: id,
      authors: const [],
      lookup: LookupState.found,
      addedAt: DateTime(2026, 11, day),
    );

class _ErroringShelf extends FakeBookshelfRepository {
  @override
  Stream<List<Volume>> watchVolumes(String uid) =>
      Stream.error(ShelfFailure.denied);
}

void main() {
  ProviderContainer makeContainer(BookshelfRepository repo, {String? uid}) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repo),
        currentUidProvider.overrideWithValue(uid),
      ],
    );
    // Riverpod 3 met en pause un provider sans listener.
    container.listen(scannedVolumesProvider, (_, _) {});
    return container;
  }

  test('lists every volume of the shelf, the newest first', () async {
    final classified = _volume('a', seriesId: 's1', number: 1, day: 1);
    final unclassified = _volume('b', day: 3);
    final orphan = _volume('c', seriesId: 'gone', number: 2, day: 2);
    final container = makeContainer(
      RecordingBookshelfRepository(
        series: const [
          Series(id: 's1', name: 'S', keys: ['s'], complete: false),
        ],
        volumes: [classified, unclassified, orphan],
      ),
      uid: 'u1',
    );
    await pumpEventQueue();

    expect(container.read(scannedVolumesProvider).value, [
      unclassified,
      orphan,
      classified,
    ]);
  });

  test('is empty without a session', () async {
    final container = makeContainer(
      RecordingBookshelfRepository(volumes: [_volume('a', day: 1)]),
    );
    await pumpEventQueue();

    expect(container.read(scannedVolumesProvider).value, isEmpty);
  });

  test('exposes stream errors', () async {
    final container = makeContainer(_ErroringShelf(), uid: 'u1');
    await pumpEventQueue();

    expect(container.read(scannedVolumesProvider).error, ShelfFailure.denied);
  });
}
