import 'package:an_ki/app/modules/birthdays_module.dart';
import 'package:an_ki/app/modules/module_data_hooks.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/core/providers/user_data_hooks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;

  /// Les crochets du registre, Anniversaires seul actif : un module désactivé
  /// garde ses données, qui partent avec le compte et suivent l'invité.
  ProviderContainer makeContainer() => ProviderContainer.test(
    retry: (_, _) => null,
    overrides: [
      firestoreProvider.overrideWithValue(db),
      activeModulesProvider.overrideWithValue([birthdaysModule]),
      ...moduleDataHooks,
    ],
  );

  Future<bool> exists(String collection, String id) async =>
      (await db.collection(collection).doc(id).get()).exists;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.collection('birthday').doc('b1').set({
      'uid': 'u1',
      'name': 'Léa',
      'surname': '',
      'date': Timestamp.fromDate(DateTime(2000, 3, 12)),
      'yearKnown': false,
      'categories': <String>[],
    });
    await db
        .collection('user')
        .doc('u1')
        .collection('categories')
        .doc('g1')
        .set({'name': 'Escalade', 'icon': 1});
    await db.collection('books').doc('k1').set({
      'uid': 'u1',
      'title': 'Dune',
      'authors': <String>[],
      'isbn': '1',
    });
    await db.collection('books').doc('k2').set({
      'uid': 'someone-else',
      'title': 'Lanfeust',
      'authors': <String>[],
      'isbn': '2',
    });
  });

  test('erases the data of every registered module, active or not', () async {
    final erasers = makeContainer().read(userDataErasersProvider);

    expect(erasers, hasLength(appModules.length));
    for (final erase in erasers) {
      await erase('u1');
    }

    expect(await exists('birthday', 'b1'), isFalse);
    expect(
      (await db.collection('user').doc('u1').collection('categories').get())
          .docs,
      isEmpty,
    );
    expect(await exists('books', 'k1'), isFalse);
    // Rien d'un autre compte.
    expect(await exists('books', 'k2'), isTrue);
  });

  test('moves the books of a guest, even with Books off', () async {
    // Anniversaires se reprend dans GuestMerge : seul Livres passe ici.
    final transfers = makeContainer().read(guestDataTransfersProvider);
    expect(transfers, hasLength(1));

    final takeOver = await transfers.single('u1', 'lea@example.com');
    final marked = (await db.collection('books').doc('k1').get()).data();
    expect(marked?['transferTo'], 'lea@example.com');

    await takeOver('target');
    final moved = (await db.collection('books').doc('k1').get()).data();
    expect(moved?['uid'], 'target');
    expect(moved?.containsKey('transferTo'), isFalse);
    expect(
      (await db.collection('books').doc('k2').get()).data()?['uid'],
      'someone-else',
    );
  });

  test('without app/, deleting or moving an account fails loudly', () {
    final container = ProviderContainer.test(retry: (_, _) => null);

    expect(() => container.read(userDataErasersProvider), throwsA(_unwired));
    expect(() => container.read(guestDataTransfersProvider), throwsA(_unwired));
  });
}

/// Échec d'un crochet que `app/` n'a pas fourni.
final _unwired = isA<ProviderException>().having(
  (error) => error.exception,
  'exception',
  isA<UnimplementedError>(),
);
