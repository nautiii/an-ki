import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import '../../../support/platform_mocks.dart';

/// Firebase Auth simulé qui note, dans l'ordre, la langue réglée puis les
/// liens de mot de passe oublié demandés.
class _ResetRecordingAuth extends MockFirebaseAuth {
  final events = <String>[];

  @override
  Future<void> setLanguageCode(String? languageCode) async =>
      events.add('language:$languageCode');

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) {
    events.add('reset:$email');
    return super.sendPasswordResetEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );
  }
}

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

  group('password reset', () {
    test('sends the link once the app language is set', () async {
      final auth = _ResetRecordingAuth();
      final repo = build(auth, FakeFirebaseFirestore());

      await repo.sendPasswordReset('lea@exemple.fr', languageCode: 'fr');

      expect(auth.events, ['language:fr', 'reset:lea@exemple.fr']);
    });

    test('translates a refusal', () async {
      for (final (code, failure) in [
        ('invalid-email', AuthFailure.invalidEmail),
        ('network-request-failed', AuthFailure.network),
        ('user-not-found', AuthFailure.userNotFound),
      ]) {
        final auth = _ResetRecordingAuth();
        whenCalling(Invocation.method(#sendPasswordResetEmail, null))
            .on(auth)
            .thenThrow(FirebaseAuthException(code: code));
        final repo = build(auth, FakeFirebaseFirestore());

        await expectLater(
          repo.sendPasswordReset('lea@exemple.fr', languageCode: 'en'),
          throwsA(failure),
          reason: code,
        );
      }
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
      // Protection contre l'énumération des e-mails : ni l'un ni l'autre.
      await expectFailure('invalid-credential', AuthFailure.invalidCredentials);
      await expectFailure('network-request-failed', AuthFailure.network);
      await expectFailure('too-many-requests', AuthFailure.tooManyRequests);
      await expectFailure('user-disabled', AuthFailure.userDisabled);
    });

    test('translates an offline anonymous sign-in', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInAnonymously, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));
      final repo = build(auth, FakeFirebaseFirestore());

      await expectLater(repo.signInAnonymously(), throwsA(AuthFailure.network));
    });

    test('maps any other code to unknown', () async {
      await expectFailure('operation-not-allowed', AuthFailure.unknown);
    });
  });

  group('signing in with Google', () {
    late GoogleSignInPlatform previousPlatform;

    setUp(() {
      previousPlatform = GoogleSignInPlatform.instance;
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(
        account: const GoogleSignInUserData(
          email: 'lea@example.com',
          id: 'google-lea',
        ),
      );
    });

    tearDown(() => GoogleSignInPlatform.instance = previousPlatform);

    /// Connexion Google refusée par Firebase avec [code].
    Future<void> expectRefused(String code, AuthFailure failure) async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInWithCredential, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: code));

      await expectLater(
        build(auth, FakeFirebaseFirestore()).signInWithGoogle(),
        throwsA(failure),
      );
    }

    test('a refused Google token is no wrong password', () async {
      await expectRefused('invalid-credential', AuthFailure.googleSignInFailed);
    });

    test('other refusals keep their meaning', () async {
      await expectRefused('network-request-failed', AuthFailure.network);
      await expectRefused('user-disabled', AuthFailure.userDisabled);
    });
  });

  group('linking a guest to Google', () {
    const camille = GoogleSignInUserData(
      email: 'camille@example.com',
      id: 'google-1',
      displayName: 'Camille Martin',
    );

    late GoogleSignInPlatform previousPlatform;

    setUp(() {
      previousPlatform = GoogleSignInPlatform.instance;
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(
        account: camille,
      );
    });

    tearDown(() => GoogleSignInPlatform.instance = previousPlatform);

    /// Session ouverte, prête à être liée. Le double de firebase_auth_mocks
    /// ne lie qu'un compte non anonyme : le dépôt, lui, ne regarde pas.
    (AuthRepository, MockUser) guestSession({
      String uid = 'guest',
      String? displayName,
    }) {
      final guest = MockUser(uid: uid, displayName: displayName);
      final auth = MockFirebaseAuth(signedIn: true, mockUser: guest);
      return (build(auth, FakeFirebaseFirestore()), guest);
    }

    test('keeps the account and takes the Google name', () async {
      final (repo, _) = guestSession();

      final linked = await repo.linkCurrentUserWithGoogle();

      expect(linked?.uid, 'guest');
      expect(linked?.displayName, 'Camille Martin');
    });

    test('keeps a name the account already has', () async {
      final (repo, _) = guestSession(displayName: 'Cam');

      final linked = await repo.linkCurrentUserWithGoogle();

      expect(linked?.displayName, 'Cam');
    });

    test('a name it cannot write never undoes the link', () async {
      final (repo, guest) = guestSession(uid: 'guest-offline-name');
      whenCalling(Invocation.method(#reload, null))
          .on(guest)
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      final linked = await repo.linkCurrentUserWithGoogle();

      expect(linked?.uid, 'guest-offline-name');
    });

    /// Liaison refusée par Firebase avec [code] : l'échec traduit, et le
    /// compte invité intact. Un compte par code : les refus programmés par
    /// mock_exceptions survivent au test, attachés aux comptes égaux.
    Future<void> expectRefused(String code, AuthFailure failure) async {
      final (repo, guest) = guestSession(uid: 'guest-$code');
      whenCalling(Invocation.method(#linkWithCredential, null))
          .on(guest)
          .thenThrow(FirebaseAuthException(code: code));

      await expectLater(repo.linkCurrentUserWithGoogle(), throwsA(failure));
      expect(repo.currentUser?.uid, 'guest-$code');
      expect(repo.currentUser?.displayName, isNull);
    }

    test('translates a Google account already used by AnKi', () async {
      await expectRefused(
        'credential-already-in-use',
        AuthFailure.credentialAlreadyInUse,
      );
    });

    test('so is its address, used by an e-mail account', () async {
      await expectRefused(
        'email-already-in-use',
        AuthFailure.credentialAlreadyInUse,
      );
    });

    test('translates the other refusals as usual', () async {
      await expectRefused('network-request-failed', AuthFailure.network);
    });

    test('without a session, links nothing', () async {
      final repo = build(MockFirebaseAuth(), FakeFirebaseFirestore());

      expect(await repo.linkCurrentUserWithGoogle(), isNull);
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
