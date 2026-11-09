import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/legacy_import.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/providers/legacy_import.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

final _now = DateTime(2026, 11, 9);

/// Anciens livres lus [reads] fois ; échoue tant que [offline].
class _Legacy extends RecordingBookshelfRepository {
  _Legacy({super.legacyBooks});

  var reads = 0;
  var offline = false;

  @override
  Future<List<LegacyBook>> fetchLegacyBooks(String uid) async {
    reads++;
    if (offline) throw ShelfFailure.offline;
    return super.fetchLegacyBooks(uid);
  }
}

void main() {
  ProviderContainer makeContainer(
    BookshelfRepository repository, {
    String? uid = 'u1',
  }) => ProviderContainer.test(
    retry: (_, _) => null,
    overrides: [
      bookshelfRepositoryProvider.overrideWithValue(repository),
      currentUidProvider.overrideWithValue(uid),
      clockProvider.overrideWithValue(() => _now),
    ],
  );

  /// Ouvre l'écran (le provider est écouté), attend l'import, le ferme.
  Future<void> openScreen(ProviderContainer container) async {
    final subscription = container.listen(legacyImportProvider, (_, _) {});
    try {
      await container.read(legacyImportProvider.future);
    } on ShelfFailure {
      // Hors ligne : l'écran s'affiche quand même.
    } finally {
      subscription.close();
      await pumpEventQueue();
    }
  }

  test('imports the legacy books into the shelf, once per session', () async {
    final repository = _Legacy(
      legacyBooks: const [
        LegacyBook(
          id: 'k1',
          title: 'One Piece - Tome 3',
          authors: [],
          isbn: '9782723488525',
        ),
        LegacyBook(id: 'k2', title: 'Dune', authors: [], isbn: '9780441172719'),
      ],
    );
    final container = makeContainer(repository);

    await openScreen(container);
    await openScreen(container);

    expect(repository.reads, 1);
    final plan = repository.importedPlans.single;
    expect(plan.entries, hasLength(2));
    expect(repository.series.single.name, 'One Piece');
    expect(
      {for (final v in repository.volumes) v.id: v.number},
      {'9782723488525': 3, '9780441172719': null},
    );
    expect(repository.volumes.first.addedAt, _now);
  });

  test('nothing to import writes nothing', () async {
    final repository = _Legacy();
    final container = makeContainer(repository);

    await openScreen(container);

    expect(repository.importedPlans, isEmpty);
  });

  test('offline, it tries again at the next opening', () async {
    final repository = _Legacy(
      legacyBooks: const [
        LegacyBook(id: 'k1', title: 'Dune', authors: [], isbn: '9780441172719'),
      ],
    )..offline = true;
    final container = makeContainer(repository);

    await openScreen(container);
    expect(repository.importedPlans, isEmpty);

    repository.offline = false;
    await openScreen(container);

    expect(repository.reads, 2);
    expect(repository.importedPlans, hasLength(1));
  });

  test('a failure is not retried while the screen stays open', () async {
    final repository = _Legacy()..offline = true;
    // Conteneur avec la relance automatique de Riverpod, comme l'app.
    final container = ProviderContainer.test(
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repository),
        currentUidProvider.overrideWithValue('u1'),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    container.listen(legacyImportProvider, (_, _) {});

    await Future<void>.delayed(const Duration(milliseconds: 800));

    expect(repository.reads, 1);
    expect(container.read(legacyImportProvider).error, ShelfFailure.offline);
  });

  test('signed out, nothing is read', () async {
    final repository = _Legacy();
    final container = makeContainer(repository, uid: null);

    await openScreen(container);

    expect(repository.reads, 0);
  });
}
