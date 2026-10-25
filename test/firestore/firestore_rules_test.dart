// Règles de sécurité Firestore (`firestore.rules`), éprouvées dans
// l'émulateur avec les accès que fait l'app (repositories de `lib/`).
//
// Lancer : `scripts/test_firestore_rules.ps1` (skill firebase), qui démarre
// l'émulateur sur le projet `demo-anki` puis exécute ce dossier. Hors
// émulateur, `flutter test` les ignore.
import 'package:flutter_test/flutter_test.dart';

import '../support/firestore_emulator.dart';

const alice = 'alice';
const bob = 'bob';
const String? signedOut = null;

Map<String, Object?> profile() => {
  'name': 'Alice',
  'surname': '',
  'categories': <Object?>[],
  'themeMode': 'system',
  'locale': 'fr',
};

Map<String, Object?> birthdayOf(String owner) => {
  'uid': owner,
  'name': 'Léa',
  'surname': 'Martin',
  'date': DateTime.utc(1990, 10, 9),
  'yearKnown': true,
  'categories': <Object?>[],
  'wishedYears': <Object?>[],
};

Map<String, Object?> bookOf(String owner) => {
  'uid': owner,
  'title': 'Dune',
  'authors': ['Frank Herbert'],
  'isbn': '9780441172719',
  'scannedAt': DateTime.utc(2026, 10, 12),
};

Map<String, Object?> userGroup() => {
  'name': 'Escalade',
  'icon': 0xe148,
  'tone': 2,
};

void main() {
  final emulator = FirestoreEmulator.fromEnvironment();

  group(
    'firestore.rules',
    skip: emulator == null
        ? 'needs the Firestore emulator: scripts/test_firestore_rules.ps1'
        : false,
    () {
      late final FirestoreEmulator db;

      setUpAll(() => db = emulator!);
      setUp(() => db.clear());
      tearDownAll(() => db.close());

      group('user/{uid} profile', () {
        test('its owner creates, reads, updates and deletes it', () async {
          expect(await db.canCreate(alice, 'user/alice', profile()), isTrue);
          expect(await db.canGet(alice, 'user/alice'), isTrue);
          expect(
            await db.canUpdate(alice, 'user/alice', {'themeMode': 'dark'}),
            isTrue,
          );
          expect(
            await db.canMerge(alice, 'user/alice', {'biometricToken': 't'}),
            isTrue,
          );
          expect(await db.canDelete(alice, 'user/alice'), isTrue);
        });

        test('nobody else reads or writes it', () async {
          await db.seed('user/alice', profile());

          expect(await db.canGet(bob, 'user/alice'), isFalse);
          expect(
            await db.canUpdate(bob, 'user/alice', {'pseudo': 'x'}),
            isFalse,
          );
          expect(await db.canDelete(bob, 'user/alice'), isFalse);
          expect(await db.canCreate(bob, 'user/carol', profile()), isFalse);
          expect(await db.canGet(signedOut, 'user/alice'), isFalse);
        });
      });

      group('user/{uid}/categories private groups', () {
        test('their owner creates, lists and deletes them', () async {
          const path = 'user/alice/categories/g1';

          expect(await db.canCreate(alice, path, userGroup()), isTrue);
          expect(await db.canQuery(alice, 'user/alice/categories'), isTrue);
          expect(await db.canDelete(alice, path), isTrue);
        });

        test('nobody else lists or writes them', () async {
          await db.seed('user/alice/categories/g1', userGroup());

          expect(await db.canQuery(bob, 'user/alice/categories'), isFalse);
          expect(
            await db.canCreate(bob, 'user/alice/categories/g2', userGroup()),
            isFalse,
          );
          expect(await db.canDelete(bob, 'user/alice/categories/g1'), isFalse);
          expect(
            await db.canQuery(signedOut, 'user/alice/categories'),
            isFalse,
          );
        });
      });

      group('birthday/{id}', () {
        test('is created only with its creator as owner', () async {
          final withoutOwner = birthdayOf(alice)..remove('uid');

          expect(
            await db.canCreate(alice, 'birthday/b1', birthdayOf(alice)),
            isTrue,
          );
          expect(
            await db.canCreate(alice, 'birthday/b2', birthdayOf(bob)),
            isFalse,
          );
          expect(
            await db.canCreate(alice, 'birthday/b3', withoutOwner),
            isFalse,
          );
          expect(
            await db.canCreate(signedOut, 'birthday/b4', birthdayOf(alice)),
            isFalse,
          );
        });

        test('is listed only through the owner filter', () async {
          await db.seed('birthday/b1', birthdayOf(alice));
          await db.seed('birthday/b2', birthdayOf(bob));

          expect(
            await db.canQuery(
              alice,
              'birthday',
              whereField: 'uid',
              isEqualTo: alice,
            ),
            isTrue,
          );
          // Les règles ne filtrent pas : sans le filtre, tout est refusé.
          expect(await db.canQuery(alice, 'birthday'), isFalse);
          expect(
            await db.canQuery(
              alice,
              'birthday',
              whereField: 'uid',
              isEqualTo: bob,
            ),
            isFalse,
          );
        });

        test('is read, updated and deleted by its owner only', () async {
          await db.seed('birthday/b1', birthdayOf(alice));

          expect(await db.canGet(alice, 'birthday/b1'), isTrue);
          expect(await db.canGet(bob, 'birthday/b1'), isFalse);
          expect(
            await db.canUpdate(alice, 'birthday/b1', {'name': 'Léo'}),
            isTrue,
          );
          // « Souhaité » : seul `wishedYears` change.
          expect(
            await db.canUpdate(alice, 'birthday/b1', {
              'wishedYears': [2026],
            }),
            isTrue,
          );
          expect(
            await db.canUpdate(bob, 'birthday/b1', {'name': 'x'}),
            isFalse,
          );
          expect(await db.canDelete(bob, 'birthday/b1'), isFalse);
          expect(await db.canDelete(alice, 'birthday/b1'), isTrue);
        });

        test('never changes owner', () async {
          await db.seed('birthday/b1', birthdayOf(alice));

          expect(
            await db.canUpdate(alice, 'birthday/b1', {'uid': bob}),
            isFalse,
          );
        });
      });

      group('books/{id}', () {
        test('follows the ownership of birthdays', () async {
          await db.seed('books/k2', bookOf(bob));

          expect(await db.canCreate(alice, 'books/k1', bookOf(alice)), isTrue);
          expect(await db.canCreate(alice, 'books/k3', bookOf(bob)), isFalse);
          expect(
            await db.canQuery(
              alice,
              'books',
              whereField: 'uid',
              isEqualTo: alice,
              orderByDescending: 'scannedAt',
            ),
            isTrue,
          );
          expect(await db.canQuery(alice, 'books'), isFalse);
          expect(await db.canGet(alice, 'books/k2'), isFalse);
          expect(await db.canUpdate(alice, 'books/k1', {'uid': bob}), isFalse);
          expect(await db.canDelete(bob, 'books/k1'), isFalse);
          expect(await db.canDelete(alice, 'books/k1'), isTrue);
        });
      });

      group('category/{id} shared groups', () {
        setUp(() => db.seed('category/family', {'name': 'Famille'}));

        test('are read by signed-in users only', () async {
          expect(await db.canQuery(alice, 'category'), isTrue);
          expect(await db.canGet(bob, 'category/family'), isTrue);
          expect(await db.canQuery(signedOut, 'category'), isFalse);
        });

        test('are never edited nor deleted', () async {
          expect(
            await db.canUpdate(alice, 'category/family', {'name': 'x'}),
            isFalse,
          );
          expect(await db.canDelete(alice, 'category/family'), isFalse);
        });

        // L'app ne crée plus de groupe partagé depuis le 2026-10-24 (groupes
        // privés) : droit à retirer des règles, voir le skill firebase.
        test('can still be created by any signed-in user', () async {
          expect(
            await db.canCreate(alice, 'category/new', userGroup()),
            isTrue,
          );
        });
      });

      test('everything else is closed', () async {
        expect(await db.canGet(alice, 'other/x'), isFalse);
        expect(await db.canCreate(alice, 'other/x', {'a': 1}), isFalse);
        expect(
          await db.canCreate(alice, 'user/alice/notes/n1', {'a': 1}),
          isFalse,
        );
      });
    },
  );
}
