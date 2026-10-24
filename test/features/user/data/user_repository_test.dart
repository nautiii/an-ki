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
    locale: 'fr',
    biometricToken: 'token-abc',
  );

  /// [user] avec d'autres valeurs pour les champs donnés.
  UserProfile userWith({
    String? pseudo,
    List<String> categories = const [],
    String? biometricToken = 'token-abc',
  }) => UserProfile(
    id: 'user-1',
    name: 'Quentin',
    surname: 'Maillard',
    pseudo: pseudo,
    categories: categories,
    locale: 'fr',
    biometricToken: biometricToken,
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
        'themeMode': 'dark',
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
          theme: ThemePreference.dark,
          locale: 'en',
          biometricToken: 'token-123',
        ),
      );
    });

    test('reads an old isDark document as a light or dark choice', () async {
      await firestore.collection('user').doc('dark').set({'isDark': true});
      await firestore.collection('user').doc('light').set({'isDark': false});

      final dark = await repository.watchUser('dark').first;
      final light = await repository.watchUser('light').first;

      expect(dark?.theme, ThemePreference.dark);
      expect(light?.theme, ThemePreference.light);
    });

    test('themeMode wins over the old isDark field', () async {
      await firestore.collection('user').doc('user-2').set({
        'isDark': true,
        'themeMode': 'system',
      });

      final watched = await repository.watchUser('user-2').first;

      expect(watched?.theme, ThemePreference.system);
    });

    test('an unknown themeMode falls back to the old field', () async {
      await firestore.collection('user').doc('user-2').set({
        'isDark': true,
        'themeMode': 'sepia',
      });

      final watched = await repository.watchUser('user-2').first;

      expect(watched?.theme, ThemePreference.dark);
    });

    test('applies defaults to an old document missing fields', () async {
      await firestore.collection('user').doc('user-3').set({});

      final watched = await repository.watchUser('user-3').first;

      expect(
        watched,
        const UserProfile(id: 'user-3', name: '', surname: '', locale: 'fr'),
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
        'themeMode': 'system',
        'locale': 'fr',
        'biometricToken': 'token-abc',
      });
    });

    test('omits the absent pseudo and biometric token', () async {
      await repository.createUser(userWith(biometricToken: null));

      final data = (await firestore.collection('user').doc('user-1').get())
          .data()!;
      expect(data.containsKey('pseudo'), isFalse);
      expect(data.containsKey('biometricToken'), isFalse);
    });
  });

  group('createUser is non-destructive (crash safety)', () {
    test('never overwrites an existing profile and returns it', () async {
      // Existing rich profile in Firestore.
      await repository.createUser(userWith(pseudo: 'Quentinou'));

      // A later (erroneous) creation with a blank default user must NOT wipe it.
      const blank = UserProfile(
        id: 'user-1',
        name: 'guest',
        surname: '',
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
        repository.updatePreferences('user-1', theme: ThemePreference.dark),
        repository.updatePreferences('user-1', locale: 'en'),
      ]);

      final data = (await firestore.collection('user').doc('user-1').get())
          .data()!;
      expect(data['themeMode'], 'dark');
      expect(data['locale'], 'en');
    });

    test('writing the theme drops the old isDark field', () async {
      await firestore.collection('user').doc('user-1').set({
        'name': 'Quentin',
        'isDark': true,
        'locale': 'fr',
      });

      await repository.updatePreferences(
        'user-1',
        theme: ThemePreference.system,
      );

      final data = (await firestore.collection('user').doc('user-1').get())
          .data()!;
      expect(data, {'name': 'Quentin', 'themeMode': 'system', 'locale': 'fr'});
    });
  });

  test('updateNames replaces the names and keeps the rest', () async {
    // Profil d'invité : sans nom, avec un pseudo choisi.
    await firestore.collection('user').doc('user-1').set({
      'name': '',
      'surname': '',
      'pseudo': 'Cam',
      'isDark': true,
      'locale': 'fr',
    });

    await repository.updateNames('user-1', name: 'Camille', surname: 'Martin');

    final data = (await firestore.collection('user').doc('user-1').get())
        .data()!;
    expect(data, {
      'name': 'Camille',
      'surname': 'Martin',
      'pseudo': 'Cam',
      'isDark': true,
      'locale': 'fr',
    });
  });

  test('addCategories adds ids without duplicates', () async {
    await repository.createUser(userWith(categories: ['fam']));

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
