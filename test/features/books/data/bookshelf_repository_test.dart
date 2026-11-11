import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/legacy_import.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf_failure.dart';
import 'package:an_ki/features/books/domain/shelf_takeover.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

final _added = DateTime(2026, 11, 8, 9, 30);

Volume _volume(
  String id, {
  String? seriesId,
  int? number,
  String title = 'One Piece',
  LookupState lookup = LookupState.found,
  List<String> authors = const ['Eiichirō Oda'],
}) => Volume(
  id: id,
  seriesId: seriesId,
  number: number,
  isbn: id,
  title: title,
  authors: authors,
  lookup: lookup,
  addedAt: _added,
);

Series _series(
  String id, {
  String name = 'One Piece',
  List<String> keys = const ['one piece'],
}) => Series(id: id, name: name, keys: keys, complete: false);

void main() {
  late FakeFirebaseFirestore db;
  late BookshelfRepository repository;

  CollectionReference<Map<String, dynamic>> seriesOf(String uid) =>
      db.collection('user').doc(uid).collection('bookSeries');
  CollectionReference<Map<String, dynamic>> volumesOf(String uid) =>
      db.collection('user').doc(uid).collection('bookVolumes');
  CollectionReference<Map<String, dynamic>> legacy() => db.collection('books');

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = BookshelfRepository(firestore: db);
  });

  group('reading', () {
    test('streams the series and volumes of one user only', () async {
      await seriesOf('u1').doc('s1').set({
        'name': 'One Piece',
        'keys': ['one piece'],
        'complete': true,
        'next': {
          'number': 109,
          'status': 'announced',
          'date': '2026-12',
          'source': 'user',
          'checkedAt': Timestamp.fromDate(_added),
        },
        'createdAt': Timestamp.fromDate(_added),
      });
      await seriesOf('u2')
          .doc('s2')
          .set({'name': 'Naruto', 'keys': <String>[]});
      await volumesOf('u1').doc('9782344059568').set({
        'seriesId': 's1',
        'number': 108,
        'isbn': '9782344059568',
        'title': 'One Piece',
        'authors': ['Eiichirō Oda'],
        'imageUrl': 'https://img/108.jpg',
        'publisher': 'Glénat',
        'publishedDate': '2024-09-04',
        'lookup': 'found',
        'addedAt': Timestamp.fromDate(_added),
      });
      await volumesOf('u2').doc('v2').set({'title': 'Naruto'});

      expect(await repository.watchSeries('u1').first, [
        Series(
          id: 's1',
          name: 'One Piece',
          keys: const ['one piece'],
          complete: true,
          next: NextVolumeInfo(
            number: 109,
            status: ReleaseStatus.announced,
            date: const ReleaseDate(year: 2026, month: 12),
            source: ReleaseSource.user,
            checkedAt: _added,
          ),
        ),
      ]);
      expect(await repository.watchVolumes('u1').first, [
        Volume(
          id: '9782344059568',
          seriesId: 's1',
          number: 108,
          isbn: '9782344059568',
          title: 'One Piece',
          authors: const ['Eiichirō Oda'],
          imageUrl: 'https://img/108.jpg',
          publisher: 'Glénat',
          publishedDate: '2024-09-04',
          lookup: LookupState.found,
          addedAt: _added,
        ),
      ]);
    });

    test('reads odd and partial documents with defaults', () async {
      await seriesOf('u1').doc('s1').set({
        'keys': ['a', 3, null],
        'complete': 'yes',
        // Statut inconnu (version plus récente) : pas d'information.
        'next': {
          'number': 2,
          'status': 'leaked',
          'source': 'bnf',
          'checkedAt': Timestamp.fromDate(_added),
        },
      });
      await seriesOf('u1').doc('s2').set({
        'name': 'Blacksad',
        'next': {
          'number': 8.0,
          'status': 'released',
          'date': 'bientôt',
          'source': 'bnf',
          'checkedAt': Timestamp.fromDate(_added),
        },
      });
      await volumesOf('u1').doc('v1').set({'number': 3.0, 'lookup': 'odd'});
      await volumesOf('u1').doc('v2').set({
        'title': 'Dune',
        'number': 2.5,
        'authors': 'Frank Herbert',
        'addedAt': '2026-11-08',
      });

      final series = await repository.watchSeries('u1').first;
      expect(series.first, _series('s1', name: '', keys: ['a']));
      expect(
        series.last.next,
        NextVolumeInfo(
          number: 8,
          status: ReleaseStatus.released,
          source: ReleaseSource.bnf,
          checkedAt: _added,
        ),
      );
      final volumes = await repository.watchVolumes('u1').first;
      expect(
        volumes.first,
        Volume(
          id: 'v1',
          number: 3,
          title: '',
          authors: const [],
          lookup: LookupState.pending,
          addedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
      expect(volumes.last.number, isNull);
      expect(volumes.last.authors, isEmpty);
      expect(volumes.last.lookup, LookupState.found);
    });

    test('fetches a shelf from the server', () async {
      await repository.createSeries('u1', _series('s1'), createdAt: _added);
      await repository.saveScannedVolume('u1', _volume('9782344059568'));

      final shelf = await repository.fetchShelf('u1');

      expect(shelf.series, [_series('s1')]);
      expect(shelf.volumes, [_volume('9782344059568')]);
      expect((await repository.fetchShelf('u2')).volumes, isEmpty);
    });
  });

  group('volumes', () {
    test('a scan writes the document of its ISBN, rescans included', () async {
      final pending = Volume(
        id: '9782344059568',
        isbn: '9782344059568',
        title: '',
        authors: const [],
        lookup: LookupState.pending,
        addedAt: _added,
      );
      await repository.saveScannedVolume('u1', pending);
      await repository.saveScannedVolume(
        'u1',
        _volume('9782344059568', seriesId: 's1', number: 108),
      );
      // Un tome en attente réécrit ensuite n'efface ni le titre, ni la série,
      // ni l'état trouvé.
      await repository.saveScannedVolume('u1', pending);

      final doc = await volumesOf('u1').doc('9782344059568').get();
      expect(doc.data(), {
        'seriesId': 's1',
        'number': 108,
        'isbn': '9782344059568',
        'title': 'One Piece',
        'authors': ['Eiichirō Oda'],
        'lookup': 'found',
        'addedAt': Timestamp.fromDate(_added),
      });
      expect((await volumesOf('u1').get()).docs, hasLength(1));
    });

    test('a volume that opens a series writes both together', () async {
      await repository.saveScannedVolume(
        'u1',
        _volume('v1', seriesId: 's1', number: 1),
        withSeries: (series: _series('s1'), createdAt: _added),
      );
      final shelf = await repository.fetchShelf('u1');
      expect(shelf.series, [_series('s1')]);
      expect(shelf.volumes, [_volume('v1', seriesId: 's1', number: 1)]);
      expect(
        (await seriesOf('u1').doc('s1').get()).data()!['createdAt'],
        Timestamp.fromDate(_added),
      );
    });

    test('with its series, a volume is still merged, not replaced', () async {
      await repository.saveScannedVolume('u1', _volume('v1'));

      await repository.saveScannedVolume(
        'u1',
        Volume(
          id: 'v1',
          seriesId: 's1',
          number: 1,
          title: '',
          authors: const [],
          lookup: LookupState.pending,
          addedAt: _added,
        ),
        withSeries: (series: _series('s1'), createdAt: _added),
      );

      final data = (await volumesOf('u1').doc('v1').get()).data()!;
      expect(
        (data['title'], data['lookup'], data['seriesId']),
        ('One Piece', 'found', 's1'),
      );
    });

    // Un lot refusé n'est pas testé ici : FakeFirebaseFirestore donne un
    // WriteBatch neuf à chaque batch(), que mock_exceptions ne peut viser ;
    // la traduction passe par le même _guard que les écritures simples.

    test('classifies, unclassifies and deletes a volume', () async {
      await repository.saveScannedVolume('u1', _volume('v1'));

      await repository.classifyVolume('u1', 'v1', seriesId: 's1', number: 4);
      var data = (await volumesOf('u1').doc('v1').get()).data()!;
      expect((data['seriesId'], data['number']), ('s1', 4));

      await repository.classifyVolume('u1', 'v1', seriesId: null, number: null);
      data = (await volumesOf('u1').doc('v1').get()).data()!;
      expect(data.containsKey('seriesId'), isFalse);
      expect(data.containsKey('number'), isFalse);

      await repository.deleteVolume('u1', 'v1');
      expect((await volumesOf('u1').doc('v1').get()).exists, isFalse);
    });

    test('translates Firestore errors into shelf failures', () async {
      await repository.saveScannedVolume('u1', _volume('v1'));
      final doc = volumesOf('u1').doc('v1');
      whenCalling(Invocation.method(#update, null))
          .on(doc)
          .thenThrow(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          );
      whenCalling(Invocation.method(#delete, null))
          .on(doc)
          .thenThrow(
            FirebaseException(plugin: 'cloud_firestore', code: 'internal'),
          );

      await expectLater(
        repository.classifyVolume('u1', 'v1', seriesId: 's', number: 1),
        throwsA(ShelfFailure.denied),
      );
      await expectLater(
        repository.deleteVolume('u1', 'v1'),
        throwsA(ShelfFailure.failed),
      );
    });
  });

  group('manual volumes', () {
    Volume manual(String id, int number, {String seriesId = 's1'}) => Volume(
      id: id,
      seriesId: seriesId,
      number: number,
      title: '',
      authors: const [],
      lookup: LookupState.found,
      addedAt: _added,
    );

    test('hands out distinct client ids', () {
      expect(repository.newVolumeId('u1'), isNotEmpty);
      expect(repository.newVolumeId('u1'), isNot(repository.newVolumeId('u1')));
    });

    test(
      'writes a new series and its volumes, without ISBN or title',
      () async {
        await repository.addManualVolumes(
          'u1',
          [manual('a', 1), manual('b', 2)],
          withSeries: (series: _series('s1'), createdAt: _added),
        );

        expect((await seriesOf('u1').doc('s1').get()).data(), {
          'name': 'One Piece',
          'keys': ['one piece'],
          'createdAt': Timestamp.fromDate(_added),
        });
        expect((await volumesOf('u1').doc('a').get()).data(), {
          'seriesId': 's1',
          'number': 1,
          'lookup': 'found',
          'addedAt': Timestamp.fromDate(_added),
        });
        final data = (await volumesOf('u1').doc('b').get()).data()!;
        expect(data['number'], 2);
        expect(data.containsKey('isbn'), isFalse);
        expect(data.containsKey('title'), isFalse);
      },
    );

    test('marks an existing series complete', () async {
      await repository.createSeries('u1', _series('s1'), createdAt: _added);

      await repository.addManualVolumes('u1', [
        manual('a', 3),
      ], completeSeriesId: 's1');

      final data = (await seriesOf('u1').doc('s1').get()).data()!;
      expect(data['complete'], isTrue);
      expect(data['keys'], ['one piece']);
      expect((await volumesOf('u1').doc('a').get()).exists, isTrue);
    });

    test('leaves the other accounts untouched', () async {
      await repository.createSeries('u2', _series('s1'), createdAt: _added);

      await repository.addManualVolumes(
        'u1',
        [manual('a', 1)],
        withSeries: (series: _series('s1'), createdAt: _added),
      );

      expect((await volumesOf('u2').get()).docs, isEmpty);
      expect((await seriesOf('u2').get()).docs, hasLength(1));
      expect((await volumesOf('u1').get()).docs, hasLength(1));
    });

    test('a refused write is a shelf failure', () async {
      // Marquer terminée une série absente : le lot est refusé.
      await expectLater(
        repository.addManualVolumes('u1', [
          manual('a', 1),
        ], completeSeriesId: 'missing'),
        throwsA(isA<ShelfFailure>()),
      );
    });
  });

  group('series', () {
    test('creates a series with a client id, dated', () async {
      final id = repository.newSeriesId('u1');
      expect(id, isNot(repository.newSeriesId('u1')));

      await repository.createSeries('u1', _series(id), createdAt: _added);

      expect((await seriesOf('u1').doc(id).get()).data(), {
        'name': 'One Piece',
        'keys': ['one piece'],
        'createdAt': Timestamp.fromDate(_added),
      });
    });

    test('a renamed series keeps its old keys', () async {
      await repository.createSeries('u1', _series('s1'), createdAt: _added);

      await repository.renameSeries(
        'u1',
        's1',
        name: 'One Piece (Glénat)',
        key: 'one piece glenat',
      );
      await repository.renameSeries(
        'u1',
        's1',
        name: 'One Piece (Glénat)',
        key: 'one piece glenat',
      );

      final data = (await seriesOf('u1').doc('s1').get()).data()!;
      expect(data['name'], 'One Piece (Glénat)');
      expect(data['keys'], ['one piece', 'one piece glenat']);
    });

    test('merges a series into another, keys and volumes included', () async {
      await repository.createSeries('u1', _series('s1'), createdAt: _added);
      await repository.createSeries(
        'u1',
        _series('s2', name: 'One-Piece', keys: ['one piece fr']),
        createdAt: _added,
      );
      await repository.createSeries(
        'u1',
        _series('s3', name: 'Naruto', keys: ['naruto']),
        createdAt: _added,
      );
      await repository.saveScannedVolume('u1', _volume('a', seriesId: 's2'));
      await repository.saveScannedVolume('u1', _volume('b', seriesId: 's3'));
      await repository.saveScannedVolume('u2', _volume('c', seriesId: 's2'));

      await repository.mergeSeries(
        'u1',
        sourceId: 's2',
        targetId: 's1',
        keys: ['one piece fr'],
      );

      expect((await seriesOf('u1').doc('s2').get()).exists, isFalse);
      expect((await seriesOf('u1').doc('s1').get()).data()!['keys'], [
        'one piece',
        'one piece fr',
      ]);
      final volumes = await repository.fetchShelf('u1');
      expect(
        {for (final v in volumes.volumes) v.id: v.seriesId},
        {'a': 's1', 'b': 's3'},
      );
      expect((await volumesOf('u2').doc('c').get()).data()!['seriesId'], 's2');
    });

    test('merging a series into itself changes nothing', () async {
      await repository.createSeries('u1', _series('s1'), createdAt: _added);

      await repository.mergeSeries(
        'u1',
        sourceId: 's1',
        targetId: 's1',
        keys: ['x'],
      );

      expect((await seriesOf('u1').doc('s1').get()).data()!['keys'], [
        'one piece',
      ]);
    });

    test('deletes a series and its volumes, nothing else', () async {
      await repository.createSeries('u1', _series('s1'), createdAt: _added);
      await repository.createSeries(
        'u1',
        _series('s2', name: 'Naruto', keys: ['naruto']),
        createdAt: _added,
      );
      await repository.createSeries('u2', _series('s1'), createdAt: _added);
      await repository.saveScannedVolume(
        'u1',
        _volume('a', seriesId: 's1', number: 1),
      );
      await repository.saveScannedVolume(
        'u1',
        _volume('b', seriesId: 's1', number: 1000),
      );
      await repository.saveScannedVolume(
        'u1',
        _volume('c', seriesId: 's2', number: 1),
      );
      await repository.saveScannedVolume('u1', _volume('d'));
      await repository.saveScannedVolume(
        'u2',
        _volume('e', seriesId: 's1', number: 1),
      );

      await repository.deleteSeries('u1', 's1');

      expect((await seriesOf('u1').doc('s1').get()).exists, isFalse);
      expect((await seriesOf('u1').doc('s2').get()).exists, isTrue);
      final left = await repository.fetchShelf('u1');
      expect({for (final v in left.volumes) v.id}, {'c', 'd'});
      // Un autre compte garde sa série du même id et son tome.
      expect((await seriesOf('u2').doc('s1').get()).exists, isTrue);
      expect((await volumesOf('u2').doc('e').get()).exists, isTrue);
    });

    test('volumes without a valid number are detached, not deleted', () async {
      await repository.createSeries('u1', _series('s1'), createdAt: _added);
      await repository.saveScannedVolume(
        'u1',
        _volume('ok', seriesId: 's1', number: 3),
      );
      await repository.saveScannedVolume('u1', _volume('none', seriesId: 's1'));
      await repository.saveScannedVolume(
        'u1',
        _volume('zero', seriesId: 's1', number: 0),
      );
      await repository.saveScannedVolume(
        'u1',
        _volume('big', seriesId: 's1', number: 1001),
      );

      await repository.deleteSeries('u1', 's1');

      expect((await seriesOf('u1').doc('s1').get()).exists, isFalse);
      expect((await volumesOf('u1').doc('ok').get()).exists, isFalse);
      for (final id in ['none', 'zero', 'big']) {
        final data = (await volumesOf('u1').doc(id).get()).data()!;
        expect(data.containsKey('seriesId'), isFalse, reason: id);
        expect(data.containsKey('number'), isFalse, reason: id);
        expect(data['title'], 'One Piece');
      }
    });

    test('a number stored as a whole double is shelved, so deleted', () async {
      // Ancien document ou saisie à la console : 3.0 se lit 3, comme ailleurs.
      await repository.createSeries('u1', _series('s1'), createdAt: _added);
      await volumesOf('u1')
          .doc('dbl')
          .set({'seriesId': 's1', 'number': 3.0, 'title': 'T3'});

      await repository.deleteSeries('u1', 's1');

      expect((await volumesOf('u1').doc('dbl').get()).exists, isFalse);
    });

    test('deleting an empty series just removes it', () async {
      await repository.createSeries('u1', _series('s1'), createdAt: _added);

      await repository.deleteSeries('u1', 's1');

      expect((await seriesOf('u1').doc('s1').get()).exists, isFalse);
    });

    test('a refused series deletion is a denied failure', () async {
      await repository.createSeries('u1', _series('s1'), createdAt: _added);
      whenCalling(Invocation.method(#delete, null))
          .on(seriesOf('u1').doc('s1'))
          .thenThrow(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          );

      await expectLater(
        repository.deleteSeries('u1', 's1'),
        throwsA(ShelfFailure.denied),
      );
    });

    test('marks complete, sets and clears the next volume', () async {
      await repository.createSeries('u1', _series('s1'), createdAt: _added);

      await repository.setSeriesComplete('u1', 's1', complete: true);
      await repository.setNextVolume(
        'u1',
        's1',
        NextVolumeInfo(
          number: 109,
          status: ReleaseStatus.announced,
          date: const ReleaseDate(year: 2026, month: 12, day: 3),
          source: ReleaseSource.googleBooks,
          checkedAt: _added,
        ),
      );
      var data = (await seriesOf('u1').doc('s1').get()).data()!;
      expect(data['complete'], isTrue);
      // La date en chaîne, jamais en Timestamp : pas de décalage de fuseau.
      expect(data['next'], {
        'number': 109,
        'status': 'announced',
        'date': '2026-12-03',
        'source': 'googleBooks',
        'checkedAt': Timestamp.fromDate(_added),
      });

      await repository.setNextVolume('u1', 's1', null);
      await repository.setSeriesComplete('u1', 's1', complete: false);
      data = (await seriesOf('u1').doc('s1').get()).data()!;
      expect(data.containsKey('next'), isFalse);
      expect(data['complete'], isFalse);
    });
  });

  group('watchFromCache', () {
    test('says the answer does not come from the cache', () async {
      await seriesOf('u1').doc('s1').set({'name': 'One Piece'});

      expect(await repository.watchFromCache('u1').first, isFalse);
    });
  });

  group('legacy books', () {
    test('lists the not yet imported books of one user', () async {
      await legacy().doc('k1').set({
        'uid': 'u1',
        'title': 'Dune',
        'authors': ['Frank Herbert'],
        'isbn': '9780441172719',
        'imageUrl': 'https://img/dune.jpg',
        'publishedDate': '1990',
        'description': 'Long',
        'pageCount': 600,
        'scannedAt': Timestamp.fromDate(_added),
      });
      await legacy().doc('k2').set({'uid': 'u1'});
      await legacy().doc('k3').set({
        'uid': 'u1',
        'importedAt': Timestamp.fromDate(_added),
      });
      await legacy().doc('k4').set({'uid': 'u2', 'title': 'Autre'});

      expect(await repository.fetchLegacyBooks('u1'), [
        LegacyBook(
          id: 'k1',
          title: 'Dune',
          authors: const ['Frank Herbert'],
          isbn: '9780441172719',
          imageUrl: 'https://img/dune.jpg',
          publishedDate: '1990',
          scannedAt: _added,
        ),
        const LegacyBook(id: 'k2', title: '', authors: [], isbn: ''),
      ]);
    });

    test('writes an import plan and marks the books imported', () async {
      await legacy().doc('k1').set({'uid': 'u1', 'title': 'One Piece T1'});
      await legacy().doc('k2').set({'uid': 'u1', 'title': 'One Piece T1'});
      await legacy().doc('k3').set({'uid': 'u1', 'title': 'Déjà là'});
      final plan = LegacyImportPlan(
        entries: [
          LegacyImportEntry(
            volume: _volume('v1', seriesId: 's1', number: 1),
            newSeries: _series('s1'),
            legacyBookIds: const ['k1', 'k2'],
          ),
          const LegacyImportEntry(legacyBookIds: ['k3']),
        ],
      );

      await repository.applyLegacyImport('u1', plan, importedAt: _added);

      expect((await repository.fetchShelf('u1')).series, [_series('s1')]);
      expect((await repository.fetchShelf('u1')).volumes, [
        _volume('v1', seriesId: 's1', number: 1),
      ]);
      expect(await repository.fetchLegacyBooks('u1'), isEmpty);
      expect(
        (await legacy().doc('k3').get()).data()!['importedAt'],
        Timestamp.fromDate(_added),
      );
    });

    test('imports more than one batch', () async {
      final entries = <LegacyImportEntry>[];
      for (var i = 0; i < 300; i++) {
        await legacy().doc('k$i').set({'uid': 'u1', 'title': 'Livre $i'});
        entries.add(
          LegacyImportEntry(volume: _volume('v$i'), legacyBookIds: ['k$i']),
        );
      }

      await repository.applyLegacyImport(
        'u1',
        LegacyImportPlan(entries: entries),
        importedAt: _added,
      );

      expect((await volumesOf('u1').get()).docs, hasLength(300));
      expect(await repository.fetchLegacyBooks('u1'), isEmpty);
    });
  });

  group('account', () {
    test('erases the shelf and the legacy books of one user', () async {
      for (var i = 0; i < 520; i++) {
        await volumesOf('u1').doc('v$i').set({'title': 'T$i'});
      }
      await seriesOf('u1').doc('s1').set({'name': 'One Piece'});
      await legacy().doc('k1').set({'uid': 'u1'});
      await legacy().doc('k2').set({'uid': 'u2'});
      await volumesOf('u2').doc('v1').set({'title': 'Autre'});

      await repository.deleteAllUserData('u1');

      expect((await volumesOf('u1').get()).docs, isEmpty);
      expect((await seriesOf('u1').get()).docs, isEmpty);
      expect((await legacy().doc('k1').get()).exists, isFalse);
      expect((await legacy().doc('k2').get()).exists, isTrue);
      expect((await volumesOf('u2').get()).docs, hasLength(1));
    });

    test('marks a guest shelf and returns what it read', () async {
      await repository.createSeries('guest', _series('s1'), createdAt: _added);
      await repository.saveScannedVolume(
        'guest',
        _volume('v1', seriesId: 's1', number: 1),
      );
      await legacy().doc('k1').set({'uid': 'guest'});
      await legacy().doc('k2').set({'uid': 'other'});

      final marked = await repository.markForTransfer('guest', 'b@x.fr');

      expect(
        marked,
        MarkedShelf(
          guestUid: 'guest',
          series: [_series('s1')],
          volumes: [_volume('v1', seriesId: 's1', number: 1)],
          legacyBookIds: const ['k1'],
        ),
      );
      for (final doc in [
        seriesOf('guest').doc('s1'),
        volumesOf('guest').doc('v1'),
        legacy().doc('k1'),
      ]) {
        expect((await doc.get()).data()!['transferTo'], 'b@x.fr');
      }
      expect(
        (await legacy().doc('k2').get()).data()!.containsKey('transferTo'),
        isFalse,
      );
    });

    test('takes a guest shelf over by its plan', () async {
      await repository.createSeries('target', _series('t1'), createdAt: _added);
      await repository.createSeries('guest', _series('s1'), createdAt: _added);
      await repository.createSeries(
        'guest',
        _series('s2', name: 'Naruto', keys: ['naruto']),
        createdAt: _added,
      );
      await repository.saveScannedVolume('guest', _volume('v1'));
      await legacy().doc('k1').set({'uid': 'guest', 'transferTo': 'b@x.fr'});
      final plan = ShelfTakeOverPlan(
        guestUid: 'guest',
        seriesToCopy: [
          _series('s2', name: 'Naruto', keys: ['naruto']),
        ],
        keysToAdd: const {
          't1': ['one piece fr'],
        },
        volumesToCopy: [_volume('v1', seriesId: 't1', number: 1)],
        guestSeriesIds: const ['s1', 's2'],
        guestVolumeIds: const ['v1'],
        legacyBookIds: const ['k1'],
      );

      await repository.takeOver('target', plan);

      final target = await repository.fetchShelf('target');
      expect(
        target.series,
        unorderedEquals([
          _series('s2', name: 'Naruto', keys: ['naruto']),
          _series('t1', keys: ['one piece', 'one piece fr']),
        ]),
      );
      expect(target.volumes, [_volume('v1', seriesId: 't1', number: 1)]);
      final guest = await repository.fetchShelf('guest');
      expect(guest.series, isEmpty);
      expect(guest.volumes, isEmpty);
      expect((await legacy().doc('k1').get()).data(), {'uid': 'target'});
    });

    test('an unreachable server is an offline failure', () async {
      whenCalling(Invocation.method(#set, null))
          .on(seriesOf('u1').doc('s1'))
          .thenThrow(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          );

      await expectLater(
        repository.createSeries('u1', _series('s1'), createdAt: _added),
        throwsA(ShelfFailure.offline),
      );
    });
  });

  group('chunkGroups', () {
    test('packs groups into batches of 500 without splitting one', () {
      final groups = [
        for (var i = 0; i < 400; i++) [for (var j = 0; j < 3; j++) i],
      ];

      final chunks = chunkGroups(groups);

      expect(chunks.map((c) => c.length), everyElement(lessThanOrEqualTo(500)));
      expect(chunks.expand((c) => c), hasLength(1200));
      // 166 groupes de 3 par lot : aucun ne chevauche deux lots.
      expect(chunks.first.length, 498);
      for (final chunk in chunks) {
        expect(chunk.length % 3, 0);
      }
    });

    test('a group larger than a batch stays alone', () {
      final chunks = chunkGroups([
        [1],
        List.filled(600, 2),
        [3],
      ]);

      expect(chunks.map((c) => c.length), [1, 600, 1]);
    });
  });
}
