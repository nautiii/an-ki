import 'package:an_ki/features/user/data/models/user_model.dart';
import 'package:an_ki/features/user/data/repositories/user_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late UserRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = UserRepository(firestore: firestore);
  });

  const user = UserModel(
    id: 'user-1',
    name: 'Quentin',
    surname: 'Maillard',
    isDark: false,
    locale: 'fr',
    biometricToken: 'token-abc',
  );

  group('fetchUser', () {
    test('returns null when the document does not exist', () async {
      expect(await repository.fetchUser('missing'), isNull);
    });

    test('returns the mapped user when it exists', () async {
      await repository.createUser(user);

      final fetched = await repository.fetchUser('user-1');

      expect(fetched, isNotNull);
      expect(fetched!.name, 'Quentin');
      expect(fetched.biometricToken, 'token-abc');
    });
  });

  test('createUser writes the document under its id', () async {
    await repository.createUser(user);

    final doc = await firestore.collection('user').doc('user-1').get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['name'], 'Quentin');
  });

  group('createUser is non-destructive (crash safety)', () {
    test('never overwrites an existing profile and returns it', () async {
      // Existing rich profile in Firestore.
      await repository.createUser(user.copyWith(pseudo: 'Quentinou'));

      // A later (erroneous) creation with a blank default user must NOT wipe it.
      const blank = UserModel(
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

  test('updateUser overwrites the existing fields', () async {
    await repository.createUser(user);

    await repository.updateUser(user.copyWith(pseudo: 'Q'));

    final doc = await firestore.collection('user').doc('user-1').get();
    expect(doc.data()!['pseudo'], 'Q');
  });

  test('updateBiometricToken updates only the token field', () async {
    await repository.createUser(user);

    await repository.updateBiometricToken('user-1', null);

    final doc = await firestore.collection('user').doc('user-1').get();
    expect(doc.data()!['biometricToken'], isNull);
    expect(doc.data()!['name'], 'Quentin');
  });

  group('fetchUserByToken', () {
    test('returns null when the document is missing', () async {
      expect(await repository.fetchUserByToken('user-1', 'token-abc'), isNull);
    });

    test('returns the user when the token matches', () async {
      await repository.createUser(user);

      final fetched = await repository.fetchUserByToken('user-1', 'token-abc');

      expect(fetched, isNotNull);
      expect(fetched!.id, 'user-1');
    });

    test('returns null when the token does not match', () async {
      await repository.createUser(user);

      expect(await repository.fetchUserByToken('user-1', 'wrong'), isNull);
    });
  });

  test('deleteUser removes the document', () async {
    await repository.createUser(user);

    await repository.deleteUser('user-1');

    final doc = await firestore.collection('user').doc('user-1').get();
    expect(doc.exists, isFalse);
  });
}
