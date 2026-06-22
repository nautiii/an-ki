import 'package:an_ki/features/auth/data/repositories/auth_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthRepository build(MockFirebaseAuth auth, FakeFirebaseFirestore firestore) =>
      AuthRepository(auth: auth, firestore: firestore);

  group('session', () {
    test('currentUser and authStateChanges reflect the signed-in user', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));
      final repo = build(auth, FakeFirebaseFirestore());

      expect(repo.currentUser?.uid, 'u1');
      expect(await repo.authStateChanges().first, isNotNull);
    });
  });

  group('sign-in / sign-up', () {
    test('signInWithEmail returns the user', () async {
      final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'u1'));
      final repo = build(auth, FakeFirebaseFirestore());

      final user = await repo.signInWithEmail(email: 'a@b.c', password: 'pwd');

      expect(user?.uid, 'u1');
    });

    test('signUp sets the display name and returns the current user', () async {
      final auth = MockFirebaseAuth();
      final repo = build(auth, FakeFirebaseFirestore());

      final user = await repo.signUp(
        email: 'a@b.c',
        password: 'pwd',
        displayName: 'New User',
      );

      expect(user, isNotNull);
    });

    test('signInAnonymously returns a user', () async {
      final auth = MockFirebaseAuth(mockUser: MockUser(isAnonymous: true));
      final repo = build(auth, FakeFirebaseFirestore());

      final user = await repo.signInAnonymously();

      expect(user, isNotNull);
    });
  });

  group('sign-out / delete', () {
    test('signOutFirebase clears the current user', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));
      final repo = build(auth, FakeFirebaseFirestore());

      await repo.signOutFirebase();

      expect(repo.currentUser, isNull);
    });

    test('deleteCurrentUser completes', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));
      final repo = build(auth, FakeFirebaseFirestore());

      await expectLater(repo.deleteCurrentUser(), completes);
    });
  });

  group('biometric token', () {
    test('setBiometricToken writes the field on the user document', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = build(MockFirebaseAuth(), firestore);

      await repo.setBiometricToken('u1', 'tok');

      final doc = await firestore.collection('user').doc('u1').get();
      expect(doc.data()?['biometricToken'], 'tok');
    });

    test('setBiometricToken(null) clears the field', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('user').doc('u1').set({'biometricToken': 'tok'});
      final repo = build(MockFirebaseAuth(), firestore);

      await repo.setBiometricToken('u1', null);

      final doc = await firestore.collection('user').doc('u1').get();
      expect(doc.data()?['biometricToken'], isNull);
    });

    test('isBiometricTokenValid matches the stored token', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('user').doc('u1').set({'biometricToken': 'tok'});
      final repo = build(MockFirebaseAuth(), firestore);

      expect(await repo.isBiometricTokenValid('u1', 'tok'), isTrue);
      expect(await repo.isBiometricTokenValid('u1', 'wrong'), isFalse);
    });

    test('isBiometricTokenValid is false when the document is missing', () async {
      final repo = build(MockFirebaseAuth(), FakeFirebaseFirestore());

      expect(await repo.isBiometricTokenValid('absent', 'tok'), isFalse);
    });
  });
}
