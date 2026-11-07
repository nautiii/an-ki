import 'dart:async';

import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Firebase Auth qui ne répond jamais à une connexion : réseau qui pend.
class _HangingAuth extends MockFirebaseAuth {
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => Completer<UserCredential>().future;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential? credential) =>
      Completer<UserCredential>().future;
}

void main() {
  /// Le dépôt tel que l'app le construit, sur Firebase simulé et le SDK
  /// Google (sa plateforme simulée quand un test en installe une).
  AuthRepository build(
    MockFirebaseAuth auth,
    FakeFirebaseFirestore firestore,
  ) => ProviderContainer.test(
    overrides: [
      firebaseAuthProvider.overrideWithValue(auth),
      firestoreProvider.overrideWithValue(firestore),
    ],
  ).read(authRepositoryProvider);

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

    test('gives up on an e-mail sign-in Firebase never answers', () async {
      final repo = AuthRepository(
        auth: _HangingAuth(),
        googleSignIn: GoogleSignIn.instance,
        firestore: FakeFirebaseFirestore(),
        signInTimeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        repo.signInWithEmail(email: 'a@b.c', password: 'pwd'),
        throwsA(AuthFailure.signInTimeout),
      );
    });

    test('waits 30 seconds by default', () {
      expect(AuthRepository.defaultSignInTimeout, const Duration(seconds: 30));
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

    test('signs in to Firebase once Google answers', () async {
      final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'firebase-lea'));

      final user = await build(
        auth,
        FakeFirebaseFirestore(),
      ).signInWithGoogle();

      expect(user?.uid, 'firebase-lea');
      expect(auth.currentUser?.uid, 'firebase-lea');
    });

    test('a refused Google token is no wrong password', () async {
      await expectRefused('invalid-credential', AuthFailure.googleSignInFailed);
    });

    test('other refusals keep their meaning', () async {
      await expectRefused('network-request-failed', AuthFailure.network);
      await expectRefused('user-disabled', AuthFailure.userDisabled);
    });

    test('gives up when Firebase never answers', () async {
      final repo = AuthRepository(
        auth: _HangingAuth(),
        googleSignIn: GoogleSignIn.instance,
        firestore: FakeFirebaseFirestore(),
        signInTimeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        repo.signInWithGoogle(),
        throwsA(AuthFailure.signInTimeout),
      );
    });

    test('confirms the identity of the signed-in account', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'reauth-google'),
      );

      await expectLater(
        build(auth, FakeFirebaseFirestore()).reauthenticateWithGoogle(),
        completes,
      );
    });

    /// Confirmation Google refusée par Firebase avec [code]. Un compte par
    /// code : les refus programmés survivent au test.
    Future<void> expectReauthRefused(String code, AuthFailure failure) async {
      final user = MockUser(uid: 'reauth-$code');
      whenCalling(Invocation.method(#reauthenticateWithCredential, null))
          .on(user)
          .thenThrow(FirebaseAuthException(code: code));
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);

      await expectLater(
        build(auth, FakeFirebaseFirestore()).reauthenticateWithGoogle(),
        throwsA(failure),
      );
    }

    test('another Google account is refused as such', () async {
      await expectReauthRefused('user-mismatch', AuthFailure.userMismatch);
    });

    test('a refused Google token is a Google failure here too', () async {
      await expectReauthRefused(
        'invalid-credential',
        AuthFailure.googleSignInFailed,
      );
    });

    test('without a session, confirms nothing', () async {
      await expectLater(
        build(
          MockFirebaseAuth(),
          FakeFirebaseFirestore(),
        ).reauthenticateWithGoogle(),
        completes,
      );
    });
  });

  group('confirming a password', () {
    test('confirms the identity with the account address', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'reauth-pwd', email: 'lea@example.com'),
      );

      await expectLater(
        build(auth, FakeFirebaseFirestore()).reauthenticateWithPassword('pwd'),
        completes,
      );
    });

    test('an account without address cannot confirm', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'reauth-no-email'),
      );

      await expectLater(
        build(auth, FakeFirebaseFirestore()).reauthenticateWithPassword('pwd'),
        throwsA(AuthFailure.requiresRecentLogin),
      );
    });

    test('translates a wrong password', () async {
      final user = MockUser(uid: 'reauth-wrong', email: 'lea@example.com');
      whenCalling(Invocation.method(#reauthenticateWithCredential, null))
          .on(user)
          .thenThrow(FirebaseAuthException(code: 'invalid-credential'));
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);

      await expectLater(
        build(auth, FakeFirebaseFirestore()).reauthenticateWithPassword('no'),
        throwsA(AuthFailure.invalidCredentials),
      );
    });

    test('without a session, confirms nothing', () async {
      await expectLater(
        build(
          MockFirebaseAuth(),
          FakeFirebaseFirestore(),
        ).reauthenticateWithPassword('pwd'),
        completes,
      );
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
      final (repo, _) = guestSession(uid: 'guest-offline-name');
      // Les refus programmés suivent les comptes égaux : celui-ci vise le
      // compte une fois renommé, le seul que la relecture voit.
      whenCalling(Invocation.method(#reload, null))
          .on(
            MockUser(uid: 'guest-offline-name', displayName: 'Camille Martin'),
          )
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      final linked = await repo.linkCurrentUserWithGoogle();

      expect(linked?.uid, 'guest-offline-name');
      // Le refus vise bien le compte que la liaison relit (le double le lève
      // sans attendre, d'où la fonction passée telle quelle).
      expect(linked!.reload, throwsA(isA<FirebaseAuthException>()));
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

    test('tells apart its address, used by an e-mail account', () async {
      await expectRefused(
        'email-already-in-use',
        AuthFailure.emailAlreadyInUse,
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

  group('opening a Google account AnKi knows', () {
    const lea = GoogleSignInUserData(email: 'lea@example.com', id: 'google-1');

    late GoogleSignInPlatform previousPlatform;

    setUp(() => previousPlatform = GoogleSignInPlatform.instance);
    tearDown(() => GoogleSignInPlatform.instance = previousPlatform);

    test('prepares with its address while the guest is still signed in, '
        'then signs in', () async {
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(account: lea);
      // Le double de firebase_auth_mocks ne connecte pas par-dessus un compte
      // anonyme : la session à préserver est ici un compte ordinaire.
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'guest'),
      );
      final repo = build(auth, FakeFirebaseFirestore());
      final prepared = <(String, String?)>[];

      final user = await repo.signInWithGoogleAccount((email) async {
        prepared.add((email, auth.currentUser?.uid));
        return true;
      });

      expect(prepared, [('lea@example.com', 'guest')]);
      expect(user, isNotNull);
    });

    test('reuses the account Google still knows, without the picker', () async {
      // Sans `account`, le sélecteur échouerait : seul le compte connu passe.
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(remembered: lea);
      final repo = build(MockFirebaseAuth(), FakeFirebaseFirestore());
      String? preparedFor;

      await repo.signInWithGoogleAccount((email) async {
        preparedFor = email;
        return true;
      });

      expect(preparedFor, 'lea@example.com');
    });

    test('opens nothing when preparing fails', () async {
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(account: lea);
      final auth = MockFirebaseAuth();
      final repo = build(auth, FakeFirebaseFirestore());

      expect(await repo.signInWithGoogleAccount((_) async => false), isNull);
      expect(auth.currentUser, isNull);
    });

    test('a refused Google token is a Google failure, other refusals keep '
        'their meaning', () async {
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(account: lea);
      for (final (code, failure) in [
        ('invalid-credential', AuthFailure.googleSignInFailed),
        ('network-request-failed', AuthFailure.network),
      ]) {
        final auth = MockFirebaseAuth();
        whenCalling(Invocation.method(#signInWithCredential, null))
            .on(auth)
            .thenThrow(FirebaseAuthException(code: code));

        await expectLater(
          build(
            auth,
            FakeFirebaseFirestore(),
          ).signInWithGoogleAccount((_) async => true),
          throwsA(failure),
          reason: code,
        );
      }
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

    test('deleteCurrentUser asks for a recent sign-in', () async {
      final user = MockUser(uid: 'delete-old');
      whenCalling(Invocation.method(#delete, null))
          .on(user)
          .thenThrow(FirebaseAuthException(code: 'requires-recent-login'));
      final repo = build(
        MockFirebaseAuth(signedIn: true, mockUser: user),
        FakeFirebaseFirestore(),
      );

      await expectLater(
        repo.deleteCurrentUser(),
        throwsA(AuthFailure.requiresRecentLogin),
      );
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
