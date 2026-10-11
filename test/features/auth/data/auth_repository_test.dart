import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

void main() {
  AuthRepository build(
    MockFirebaseAuth auth,
    FakeFirebaseFirestore firestore,
  ) => AuthRepository(
    auth: auth,
    googleSignIn: GoogleSignIn.instance,
    firestore: firestore,
  );

  group('session', () {
    test('currentUser and userChanges reflect the signed-in user', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1'),
      );
      final repo = build(auth, FakeFirebaseFirestore());

      expect(repo.currentUser?.uid, 'u1');
      expect((await repo.userChanges().first)?.uid, 'u1');
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

  group('failure translation', () {
    Future<void> expectFailure(String code, AuthFailure failure) async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: code));
      final repo = build(auth, FakeFirebaseFirestore());

      await expectLater(
        repo.signInWithEmail(email: 'a@b.c', password: 'pwd'),
        throwsA(failure),
      );
    }

    test('maps the documented Firebase Auth codes', () async {
      await expectFailure('weak-password', AuthFailure.weakPassword);
      await expectFailure(
        'email-already-in-use',
        AuthFailure.emailAlreadyInUse,
      );
      await expectFailure('invalid-email', AuthFailure.invalidEmail);
      await expectFailure('user-not-found', AuthFailure.userNotFound);
      await expectFailure('wrong-password', AuthFailure.wrongPassword);
    });

    test('maps any other code to unknown', () async {
      await expectFailure('too-many-requests', AuthFailure.unknown);
    });
  });

  group('sign-out / delete', () {
    test('signOutFirebase clears the current user', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1'),
      );
      final repo = build(auth, FakeFirebaseFirestore());

      await repo.signOutFirebase();

      expect(repo.currentUser, isNull);
    });

    test('deleteCurrentUser completes', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1'),
      );
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
      await firestore.collection('user').doc('u1').set({
        'biometricToken': 'tok',
      });
      final repo = build(MockFirebaseAuth(), firestore);

      await repo.setBiometricToken('u1', null);

      final doc = await firestore.collection('user').doc('u1').get();
      expect(doc.data()?['biometricToken'], isNull);
    });

    test('isBiometricTokenValid matches the stored token', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('user').doc('u1').set({
        'biometricToken': 'tok',
      });
      final repo = build(MockFirebaseAuth(), firestore);

      expect(await repo.isBiometricTokenValid('u1', 'tok'), isTrue);
      expect(await repo.isBiometricTokenValid('u1', 'wrong'), isFalse);
    });

    test(
      'isBiometricTokenValid is false when the document is missing',
      () async {
        final repo = build(MockFirebaseAuth(), FakeFirebaseFirestore());

        expect(await repo.isBiometricTokenValid('absent', 'tok'), isFalse);
      },
    );
  });
}
