import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late UserRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = UserRepository(firestore: firestore);
  });

  const user = UserProfile(
    id: 'user-1',
    name: 'Quentin',
    surname: 'Maillard',
    isDark: false,
    locale: 'fr',
    biometricToken: 'token-abc',
  );

  group('watchUser', () {
    test('emits null while the document does not exist', () async {
      expect(await repository.watchUser('missing').first, isNull);
    });

    test('emits the mapped user when it exists', () async {
      await repository.createUser(user);

      // Le faux Firestore applique la transaction un tick plus tard.
      final watched = await repository
          .watchUser('user-1')
          .firstWhere((user) => user != null);

      expect(watched, user);
    });

    test('maps every field of a complete document', () async {
      await firestore.collection('user').doc('user-2').set({
        'name': 'Quentin',
        'surname': 'Maillard',
        'pseudo': 'Q',
        'categories': ['family', 'friend'],
        'isDark': true,
        'locale': 'en',
        'biometricToken': 'token-123',
      });

      final watched = await repository.watchUser('user-2').first;

      expect(
        watched,
        const UserProfile(
          id: 'user-2',
          name: 'Quentin',
          surname: 'Maillard',
          pseudo: 'Q',
          categories: ['family', 'friend'],
          isDark: true,
          locale: 'en',
          biometricToken: 'token-123',
        ),
      );
    });

    test('applies defaults to an old document missing fields', () async {
      await firestore.collection('user').doc('user-3').set({});

      final watched = await repository.watchUser('user-3').first;

      expect(
        watched,
        const UserProfile(
          id: 'user-3',
          name: '',
          surname: '',
          isDark: false,
          locale: 'fr',
        ),
      );
    });
  });

  group('createUser', () {
    test('writes the document under its id', () async {
      await repository.createUser(user);

      final doc = await firestore.collection('user').doc('user-1').get();
      expect(doc.data(), {
        'name': 'Quentin',
        'surname': 'Maillard',
        'categories': <String>[],
        'isDark': false,
        'locale': 'fr',
        'biometricToken': 'token-abc',
      });
    });

    test('omits the absent pseudo and biometric token', () async {
      await repository.createUser(user.copyWith(clearBiometricToken: true));

      final data = (await firestore.collection('user').doc('user-1').get())
          .data()!;
      expect(data.containsKey('pseudo'), isFalse);
      expect(data.containsKey('biometricToken'), isFalse);
    });
  });

  group('createUser is non-destructive (crash safety)', () {
    test('never overwrites an existing profile and returns it', () async {
      // Existing rich profile in Firestore.
      await repository.createUser(user.copyWith(pseudo: 'Quentinou'));

      // A later (erroneous) creation with a blank default user must NOT wipe it.
      const blank = UserProfile(
        id: 'user-1',
        name: 'guest',
        surname: '',
        isDark: false,
        locale: 'fr',
      );
      final effective = await repository.createUser(blank);

      // The returned user is the existing one, not the blank default.
      expect(effective.pseudo, 'Quentinou');
      expect(effective.biometricToken, 'token-abc');

      // The stored document is untouched.
      final doc = await firestore.collection('user').doc('user-1').get();
      expect(doc.data()!['pseudo'], 'Quentinou');
      expect(doc.data()!['biometricToken'], 'token-abc');
      expect(doc.data()!['name'], 'Quentin');
    });

    test('creates the document when absent and returns the new user', () async {
      final effective = await repository.createUser(user);

      expect(effective.id, 'user-1');
      final doc = await firestore.collection('user').doc('user-1').get();
      expect(doc.exists, isTrue);
    });
  });

  group('updatePreferences', () {
    test('writes only the given fields', () async {
      await repository.createUser(user);

      await repository.updatePreferences('user-1', pseudo: 'Q');

      final data = (await firestore.collection('user').doc('user-1').get())
          .data()!;
      expect(data['pseudo'], 'Q');
      expect(data['locale'], 'fr');
      expect(data['biometricToken'], 'token-abc');
    });

    test('two quick edits do not overwrite each other', () async {
      await repository.createUser(user);

      await Future.wait([
        repository.updatePreferences('user-1', isDark: true),
        repository.updatePreferences('user-1', locale: 'en'),
      ]);

      final data = (await firestore.collection('user').doc('user-1').get())
          .data()!;
      expect(data['isDark'], isTrue);
      expect(data['locale'], 'en');
    });
  });

  test('addCategories adds ids without duplicates', () async {
    await repository.createUser(user.copyWith(categories: ['fam']));

    await repository.addCategories('user-1', ['fam', 'friend']);

    final data = (await firestore.collection('user').doc('user-1').get())
        .data()!;
    expect(data['categories'], ['fam', 'friend']);
  });

  test('deleteUser removes the document', () async {
    await repository.createUser(user);

    await repository.deleteUser('user-1');

    final doc = await firestore.collection('user').doc('user-1').get();
    expect(doc.exists, isFalse);
  });
}
