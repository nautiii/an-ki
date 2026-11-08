import 'dart:async';

import 'package:an_ki/app/modules/module_data_hooks.dart';
import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/books/data/book_repository.dart';
import 'package:an_ki/features/settings/domain/guest_merge_failure.dart';
import 'package:an_ki/features/settings/providers/guest_merge.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../support/fake_providers.dart';

const _guest = 'guest';
const _target = FakeAuthRepository.googleUid;

/// Anniversaires dont la lecture serveur échoue avec [error] : hors ligne.
class _UnreachableBirthdays extends BirthdayRepository {
  _UnreachableBirthdays(FakeFirebaseFirestore firestore, this.error)
    : super(firestore: firestore);

  final Exception error;

  @override
  Future<List<Birthday>> markForTransfer(String uid, String email) async =>
      throw error;
}

/// Anniversaires dont la reprise échoue, après la connexion.
class _FailingTakeOver extends BirthdayRepository {
  _FailingTakeOver(FakeFirebaseFirestore firestore)
    : super(firestore: firestore);

  @override
  Future<void> takeOver(
    String uid, {
    required Map<String, List<String>> moves,
    required Iterable<String> duplicates,
  }) async => throw FirebaseException(
    plugin: 'cloud_firestore',
    code: 'permission-denied',
  );
}

/// Livres dont les marques échouent avec [error], ou n'arrivent jamais sans
/// erreur : avant la connexion. [takeOverError] : leur reprise échoue, après.
class _FragileBooks extends BookRepository {
  _FragileBooks(
    FakeFirebaseFirestore firestore, {
    this.error,
    this.neverMarks = false,
    this.takeOverError,
  }) : super(
         firestore: firestore,
         httpClient: MockClient((_) async => http.Response('', 500)),
         apiKey: '',
       );

  final Exception? error;
  final bool neverMarks;
  final Exception? takeOverError;

  @override
  Future<List<String>> markForTransfer(String uid, String email) {
    if (error case final error?) throw error;
    if (neverMarks) return Completer<List<String>>().future;
    return super.markForTransfer(uid, email);
  }

  @override
  Future<void> takeOver(String uid, Iterable<String> bookIds) {
    if (takeOverError case final error?) throw error;
    return super.takeOver(uid, bookIds);
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late FakeAuthRepository auth;

  CollectionReference<Map<String, dynamic>> groupsOf(String uid) =>
      db.collection('user').doc(uid).collection('categories');

  Future<void> seedBirthday(
    String id,
    String uid,
    String name, {
    int month = 10,
    int day = 9,
    List<String> categories = const [],
  }) => db.collection('birthday').doc(id).set({
    'uid': uid,
    'name': name,
    'surname': '',
    'date': Timestamp.fromDate(DateTime(2000, month, day)),
    'yearKnown': false,
    'categories': categories,
  });

  Future<Map<String, dynamic>?> birthday(String id) async =>
      (await db.collection('birthday').doc(id).get()).data();

  Future<Map<String, dynamic>?> book(String id) async =>
      (await db.collection('books').doc(id).get()).data();

  /// [wired] : `app/` fournit les reprises des modules, comme dans `main()`.
  ProviderContainer makeContainer({
    BirthdayRepository? birthdays,
    BookRepository? books,
    bool wired = true,
  }) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        if (wired) ...moduleDataHooks,
        firestoreProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(auth),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        if (birthdays != null)
          birthdayRepositoryProvider.overrideWithValue(birthdays),
        if (books != null) bookRepositoryProvider.overrideWithValue(books),
      ],
    );
    container.listen(guestMergeProvider, (_, _) {});
    return container;
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    auth = FakeAuthRepository(user: MockUser(uid: _guest, isAnonymous: true));
    // Invité : Léa (déjà dans le compte), Tom, ses groupes, un livre, son
    // profil. Compte Google : Léa et son groupe « escalade ».
    await seedBirthday('b1', _guest, 'Léa', categories: ['g1']);
    await seedBirthday(
      'b2',
      _guest,
      'Tom',
      month: 2,
      day: 1,
      categories: ['g1', 'g2', 'family'],
    );
    await groupsOf(_guest).doc('g1').set({'name': 'Escalade', 'icon': 1});
    await groupsOf(_guest).doc('g2').set({'name': 'Voisins', 'icon': 2});
    await db.collection('books').doc('k1').set({
      'uid': _guest,
      'title': 'Dune',
      'authors': <String>[],
      'isbn': '1',
    });
    await db.collection('user').doc(_guest).set({'name': ''});
    await seedBirthday('t1', _target, 'lea');
    await groupsOf(_target).doc('tg').set({'name': 'escalade', 'icon': 3});
  });

  test('opens the Google account with the guest data, without duplicates '
      'nor orphans', () async {
    final container = makeContainer();

    final plan = await container.read(guestMergeProvider.notifier).merge();

    expect(plan?.moves, {
      'b2': ['tg', 'g2', 'family'],
    });
    expect(plan?.duplicates, ['b1']);
    expect(plan?.newGroups, [
      const BirthdayCategory(id: 'g2', name: 'Voisins', icon: 2),
    ]);
    expect(auth.currentUser?.uid, _target);
    expect(container.read(guestMergeProvider), isA<AsyncData<void>>());

    // Tom est au compte, sans marque ; Léa n'est pas doublée.
    final tom = await birthday('b2');
    expect(tom?['uid'], _target);
    expect(tom?['categories'], ['tg', 'g2', 'family']);
    expect(tom?.containsKey('transferTo'), isFalse);
    expect(await birthday('b1'), isNull);
    expect((await birthday('t1'))?['uid'], _target);
    // Groupes : « Voisins » recréé chez le compte, rien chez l'invité.
    expect(
      (await groupsOf(_target).get()).docs.map((doc) => doc.id),
      unorderedEquals(['g2', 'tg']),
    );
    expect((await groupsOf(_guest).get()).docs, isEmpty);
    // Livre repris, profil d'invité effacé.
    final book = (await db.collection('books').doc('k1').get()).data();
    expect(book?['uid'], _target);
    expect(book?.containsKey('transferTo'), isFalse);
    expect((await db.collection('user').doc(_guest).get()).exists, isFalse);
  });

  test('marks the guest data before signing in', () async {
    final marks = <String?>[];
    auth = _MarkWatchingAuth(
      onPrepared: () async =>
          marks.add((await birthday('b2'))?['transferTo'] as String?),
    );

    await makeContainer().read(guestMergeProvider.notifier).merge();

    expect(marks, [FakeAuthRepository.googleEmail]);
  });

  test('a guest without a profile moves all the same', () async {
    await db.collection('user').doc(_guest).delete();
    final container = makeContainer();

    expect(
      await container.read(guestMergeProvider.notifier).merge(),
      isNotNull,
    );

    expect(container.read(guestMergeProvider), isA<AsyncData<void>>());
    expect((await birthday('b2'))?['uid'], _target);
  });

  test('ignores a second tap while it runs', () async {
    final container = makeContainer();
    final guestMerge = container.read(guestMergeProvider.notifier);

    final first = guestMerge.merge();
    expect(await guestMerge.merge(), isNull);

    expect(await first, isNotNull);
    expect(
      auth.calls.where((call) => call == 'signInWithGoogleAccount'),
      hasLength(1),
    );
  });

  test('does nothing without a session', () async {
    auth = FakeAuthRepository();
    final container = makeContainer();

    expect(await container.read(guestMergeProvider.notifier).merge(), isNull);

    expect(auth.calls, isEmpty);
    expect((await birthday('b2'))?.containsKey('transferTo'), isFalse);
  });

  test('a closed Google picker changes nothing', () async {
    auth.googleAccountFailure = const GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
    );
    final container = makeContainer();

    expect(await container.read(guestMergeProvider.notifier).merge(), isNull);

    expect(container.read(guestMergeProvider), isA<AsyncData<void>>());
    expect(auth.currentUser?.uid, _guest);
    expect((await birthday('b2'))?.containsKey('transferTo'), isFalse);
  });

  test('reports a refused sign-in as such', () async {
    auth.googleAccountFailure = AuthFailure.network;
    final container = makeContainer();

    expect(await container.read(guestMergeProvider.notifier).merge(), isNull);

    expect(container.read(guestMergeProvider).error, AuthFailure.network);
  });

  for (final (name, error) in [
    (
      'an unreachable server',
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    ),
    ('marks that never arrive', TimeoutException('marks')),
  ]) {
    test('offline ($name): the guest stays a guest', () async {
      final container = makeContainer(
        birthdays: _UnreachableBirthdays(db, error),
      );

      expect(await container.read(guestMergeProvider.notifier).merge(), isNull);

      expect(
        container.read(guestMergeProvider).error,
        GuestMergeFailure.offline,
      );
      expect(auth.currentUser?.uid, _guest);
      expect(auth.calls, isNot(contains('signOutFirebase')));
    });
  }

  test('another failure before signing in keeps the guest too', () async {
    final container = makeContainer(
      birthdays: _UnreachableBirthdays(
        db,
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
    );

    await container.read(guestMergeProvider.notifier).merge();

    expect(container.read(guestMergeProvider).error, GuestMergeFailure.failed);
    expect(auth.currentUser?.uid, _guest);
  });

  test(
    'says when the account opened but the birthdays did not follow',
    () async {
      final container = makeContainer(birthdays: _FailingTakeOver(db));

      expect(await container.read(guestMergeProvider.notifier).merge(), isNull);

      expect(
        container.read(guestMergeProvider).error,
        GuestMergeFailure.incomplete,
      );
      expect(auth.currentUser?.uid, _target);
    },
  );

  test(
    'without the module transfers, marks nothing and keeps the guest',
    () async {
      final container = makeContainer(wired: false);

      expect(await container.read(guestMergeProvider.notifier).merge(), isNull);

      expect(
        container.read(guestMergeProvider).error,
        GuestMergeFailure.failed,
      );
      expect(auth.calls, isEmpty);
      expect((await birthday('b2'))?.containsKey('transferTo'), isFalse);
    },
  );

  group('books', () {
    test('are marked before signing in', () async {
      final marks = <String?>[];
      auth = _MarkWatchingAuth(
        onPrepared: () async =>
            marks.add((await book('k1'))?['transferTo'] as String?),
      );

      await makeContainer().read(guestMergeProvider.notifier).merge();

      expect(marks, [FakeAuthRepository.googleEmail]);
    });

    test('offline, the guest stays a guest', () async {
      final container = makeContainer(
        books: _FragileBooks(
          db,
          error: FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          ),
        ),
      );

      expect(await container.read(guestMergeProvider.notifier).merge(), isNull);

      expect(
        container.read(guestMergeProvider).error,
        GuestMergeFailure.offline,
      );
      expect(auth.currentUser?.uid, _guest);
      expect((await book('k1'))?['uid'], _guest);
    });

    testWidgets('marks that never arrive: the guest stays a guest', (
      tester,
    ) async {
      final container = makeContainer(
        books: _FragileBooks(db, neverMarks: true),
      );

      final merged = container.read(guestMergeProvider.notifier).merge();
      // Les marques des livres comptent dans le délai de toutes les marques.
      await tester.pump(GuestMerge.markTimeout + const Duration(seconds: 1));

      expect(await merged, isNull);
      expect(
        container.read(guestMergeProvider).error,
        GuestMergeFailure.offline,
      );
      expect(auth.currentUser?.uid, _guest);
    });

    test('that do not follow make the move incomplete', () async {
      final container = makeContainer(
        books: _FragileBooks(
          db,
          takeOverError: FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
      );

      expect(await container.read(guestMergeProvider.notifier).merge(), isNull);

      expect(
        container.read(guestMergeProvider).error,
        GuestMergeFailure.incomplete,
      );
      expect(auth.currentUser?.uid, _target);
      // Les anniversaires sont passés avant, le profil d'invité reste.
      expect((await birthday('b2'))?['uid'], _target);
      expect((await db.collection('user').doc(_guest).get()).exists, isTrue);
    });
  });
}

/// Compte Google ouvert après un regard sur les données, une fois l'invité
/// prêt : [onPrepared] voit ce que l'invité a écrit avant la connexion.
class _MarkWatchingAuth extends FakeAuthRepository {
  _MarkWatchingAuth({required this.onPrepared})
    : super(user: MockUser(uid: _guest, isAnonymous: true));

  final Future<void> Function() onPrepared;

  @override
  Future<User?> signInWithGoogleAccount(
    Future<bool> Function(String email) prepare,
  ) => super.signInWithGoogleAccount((email) async {
    final ready = await prepare(email);
    await onPrepared();
    return ready;
  });
}
