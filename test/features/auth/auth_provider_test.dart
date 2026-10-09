import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import '../../support/platform_mocks.dart';

/// AuthRepository whose biometric lookup always throws, to drive the error path.
class _ThrowingAuthRepository extends AuthRepository {
  _ThrowingAuthRepository(MockFirebaseAuth auth)
    : super(
        auth: auth,
        googleSignIn: GoogleSignIn.instance,
        firestore: FakeFirebaseFirestore(),
      );

  @override
  Future<bool> isBiometricTokenValid(String uid, String token) async =>
      throw Exception('lookup failed');
}

/// AuthRepository whose Google sign-in fails in the plugin with [error].
class _GoogleFailingAuthRepository extends AuthRepository {
  _GoogleFailingAuthRepository(this.error)
    : super(
        auth: MockFirebaseAuth(),
        googleSignIn: GoogleSignIn.instance,
        firestore: FakeFirebaseFirestore(),
      );

  final GoogleSignInException error;

  @override
  Future<User?> signInWithGoogle() async => throw error;
}

const _tokenKey = 'biometric_auth_token';
const _uidKey = 'biometric_user_id';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBiometricChannels channels;

  setUpAll(() async {
    GoogleSignInPlatform.instance = FakeGoogleSignInPlatform();
    await GoogleSignIn.instance.initialize();
  });

  setUp(() {
    channels = FakeBiometricChannels()..install();
  });

  tearDown(() => channels.uninstall());

  MockUser buildUser({bool anonymous = false, String uid = 'uid-1'}) =>
      MockUser(
        uid: uid,
        email: 'test@example.com',
        displayName: 'Test User',
        isAnonymous: anonymous,
      );

  ProviderContainer makeContainer(
    MockFirebaseAuth auth, {
    FakeFirebaseFirestore? firestore,
    AuthRepository? repository,
  }) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          repository ??
              AuthRepository(
                auth: auth,
                googleSignIn: GoogleSignIn.instance,
                firestore: firestore ?? FakeFirebaseFirestore(),
              ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('AuthState', () {
    test('isAuthenticated relies on biometrics when configured', () {
      final state = AuthState(canUseBiometrics: true);
      expect(state.isAuthenticated, isFalse);
      expect(
        state.copyWith(isBiometricallyAuthenticated: true).isAuthenticated,
        isTrue,
      );
    });

    test('isAuthenticated falls back to the Firebase session', () {
      expect(AuthState(user: buildUser()).isAuthenticated, isTrue);
      expect(AuthState().isAuthenticated, isFalse);
    });

    test('isAnonymous and uid expose the user details', () {
      expect(AuthState(user: buildUser(anonymous: true)).isAnonymous, isTrue);
      expect(AuthState(user: buildUser()).uid, 'uid-1');
      expect(AuthState(biometricUid: 'bio').uid, 'bio');
    });
  });

  group('email/password', () {
    test('signIn succeeds and stores the user', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser());
      final container = makeContainer(auth);

      final ok = await container
          .read(authProvider.notifier)
          .signIn(email: 'test@example.com', password: 'pwd');

      expect(ok, isTrue);
      expect(container.read(authProvider).user?.uid, 'uid-1');
    });

    test('signIn maps FirebaseAuthException codes to messages', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser());
      whenCalling(Invocation.method(#signInWithEmailAndPassword, []))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));
      final container = makeContainer(auth);

      final ok = await container
          .read(authProvider.notifier)
          .signIn(email: 'test@example.com', password: 'bad');

      expect(ok, isFalse);
      expect(container.read(authProvider).failure, AuthFailure.wrongPassword);
    });

    test('signIn maps unexpected errors to a generic message', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser());
      whenCalling(Invocation.method(#signInWithEmailAndPassword, []))
          .on(auth)
          .thenThrow(Exception('network'));
      final container = makeContainer(auth);

      final ok = await container
          .read(authProvider.notifier)
          .signIn(email: 'x', password: 'y');

      expect(ok, isFalse);
      expect(container.read(authProvider).failure, AuthFailure.signInFailed);
    });

    test('signUp succeeds', () async {
      final auth = MockFirebaseAuth();
      final container = makeContainer(auth);

      final ok = await container
          .read(authProvider.notifier)
          .signUp(
            email: 'new@example.com',
            password: 'pwd',
            name: 'New',
            surname: 'User',
          );

      expect(ok, isTrue);
      expect(container.read(authProvider).user, isNotNull);
    });

    test('signUp maps the weak-password code', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, []))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'weak-password'));
      final container = makeContainer(auth);

      final ok = await container
          .read(authProvider.notifier)
          .signUp(email: 'x', password: 'y', name: 'N', surname: 'S');

      expect(ok, isFalse);
      expect(container.read(authProvider).failure, AuthFailure.weakPassword);
    });

    test('signUp maps unexpected errors to the registration message', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, []))
          .on(auth)
          .thenThrow(Exception('boom'));
      final container = makeContainer(auth);

      final ok = await container
          .read(authProvider.notifier)
          .signUp(email: 'x', password: 'y', name: 'N', surname: 'S');

      expect(ok, isFalse);
      expect(container.read(authProvider).failure, AuthFailure.signUpFailed);
    });

    test('a new operation clears the previous failure', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser(anonymous: true));
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));
      final container = makeContainer(auth);
      final notifier = container.read(authProvider.notifier);
      await notifier.signIn(email: 'a', password: 'bad');
      expect(container.read(authProvider).failure, AuthFailure.wrongPassword);

      await notifier.signInAnonymously();

      expect(container.read(authProvider).failure, isNull);
    });

    test('maps the documented Firebase codes to failures', () async {
      Future<AuthFailure?> failureFor(String code) async {
        final auth = MockFirebaseAuth(mockUser: buildUser());
        whenCalling(Invocation.method(#signInWithEmailAndPassword, []))
            .on(auth)
            .thenThrow(FirebaseAuthException(code: code));
        final container = makeContainer(auth);
        await container
            .read(authProvider.notifier)
            .signIn(email: 'a', password: 'b');
        return container.read(authProvider).failure;
      }

      expect(await failureFor('invalid-email'), AuthFailure.invalidEmail);
      expect(await failureFor('user-not-found'), AuthFailure.userNotFound);
      expect(
        await failureFor('email-already-in-use'),
        AuthFailure.emailAlreadyInUse,
      );
      expect(await failureFor('something-else'), AuthFailure.unknown);
    });
  });

  group('google', () {
    Future<ProviderContainer> signInFailingWith(
      GoogleSignInExceptionCode code,
    ) async {
      final container = makeContainer(
        MockFirebaseAuth(),
        repository: _GoogleFailingAuthRepository(
          GoogleSignInException(code: code),
        ),
      );
      final ok = await container.read(authProvider.notifier).signInWithGoogle();
      expect(ok, isFalse);
      return container;
    }

    test('a cancelled Google sign-in is not reported as a failure', () async {
      final container = await signInFailingWith(
        GoogleSignInExceptionCode.canceled,
      );

      expect(container.read(authProvider).failure, isNull);
      expect(container.read(authProvider).isLoading, isFalse);
    });

    test('a Google plugin error is reported', () async {
      final container = await signInFailingWith(
        GoogleSignInExceptionCode.unknownError,
      );

      expect(
        container.read(authProvider).failure,
        AuthFailure.googleSignInFailed,
      );
    });
  });

  group('anonymous', () {
    test('signInAnonymously succeeds', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser(anonymous: true));
      final container = makeContainer(auth);

      final ok = await container
          .read(authProvider.notifier)
          .signInAnonymously();

      expect(ok, isTrue);
      expect(container.read(authProvider).user, isNotNull);
    });

    test('signInAnonymously reports failures', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInAnonymously, []))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'operation-not-allowed'));
      final container = makeContainer(auth);

      final ok = await container
          .read(authProvider.notifier)
          .signInAnonymously();

      expect(ok, isFalse);
      expect(container.read(authProvider).failure, AuthFailure.unknown);
    });
  });

  group('signOut', () {
    test('a full sign-out clears the Firebase user', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
      final container = makeContainer(auth);
      await container
          .read(authProvider.notifier)
          .signIn(email: 'a', password: 'b');

      await container.read(authProvider.notifier).signOut();

      expect(container.read(authProvider).user, isNull);
    });

    test('a biometric lock keeps the Firebase session', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser());
      final container = makeContainer(auth);
      await container
          .read(authProvider.notifier)
          .signIn(email: 'a', password: 'b');
      channels.storage[_tokenKey] = 'tok'; // biometric configured

      await container.read(authProvider.notifier).signOut();

      expect(container.read(authProvider).user, isNotNull);
      expect(
        container.read(authProvider).isBiometricallyAuthenticated,
        isFalse,
      );
    });
  });

  group('biometrics', () {
    test('enableBiometrics stores a token and flips the flag', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
      final firestore = FakeFirebaseFirestore();
      final container = makeContainer(auth, firestore: firestore);

      await container.read(authProvider.notifier).enableBiometrics();

      expect(container.read(authProvider).canUseBiometrics, isTrue);
      expect(channels.storage[_tokenKey], isNotNull);
      final doc = await firestore.collection('user').doc('uid-1').get();
      expect(doc.data()?['biometricToken'], isNotNull);
    });

    test('enableBiometrics is a no-op without a signed-in user', () async {
      final auth = MockFirebaseAuth();
      final container = makeContainer(auth);

      await container.read(authProvider.notifier).enableBiometrics();

      expect(channels.storage[_tokenKey], isNull);
    });

    test('disableBiometrics clears stored data', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
      final container = makeContainer(auth);
      await container.read(authProvider.notifier).enableBiometrics();

      await container.read(authProvider.notifier).disableBiometrics();

      expect(container.read(authProvider).canUseBiometrics, isFalse);
      expect(channels.storage[_tokenKey], isNull);
    });

    group('signInWithBiometricToken', () {
      test('succeeds when the stored token matches', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('user').doc('uid-1').set({
          'biometricToken': 'tok',
        });
        channels.storage[_tokenKey] = 'tok';
        channels.storage[_uidKey] = 'uid-1';
        final container = makeContainer(
          MockFirebaseAuth(),
          firestore: firestore,
        );

        final ok = await container
            .read(authProvider.notifier)
            .signInWithBiometricToken();

        expect(ok, isTrue);
        expect(container.read(authProvider).isBiometricallyAuthenticated, true);
        expect(container.read(authProvider).biometricUid, 'uid-1');
      });

      test('fails when the biometric check is rejected', () async {
        channels.authenticateResult = false;
        final container = makeContainer(MockFirebaseAuth());

        final ok = await container
            .read(authProvider.notifier)
            .signInWithBiometricToken();

        expect(ok, isFalse);
      });

      test('fails when there is no stored token', () async {
        final container = makeContainer(MockFirebaseAuth());

        final ok = await container
            .read(authProvider.notifier)
            .signInWithBiometricToken();

        expect(ok, isFalse);
        expect(container.read(authProvider).canUseBiometrics, isFalse);
      });

      test('clears data when the token is no longer valid', () async {
        channels.storage[_tokenKey] = 'tok';
        channels.storage[_uidKey] = 'uid-1';
        // Firestore has no matching document → token invalid.
        final container = makeContainer(MockFirebaseAuth());

        final ok = await container
            .read(authProvider.notifier)
            .signInWithBiometricToken();

        expect(ok, isFalse);
        expect(channels.storage[_tokenKey], isNull);
      });

      test('reports an error when the lookup throws', () async {
        channels.storage[_tokenKey] = 'tok';
        channels.storage[_uidKey] = 'uid-1';
        final container = makeContainer(
          MockFirebaseAuth(),
          repository: _ThrowingAuthRepository(MockFirebaseAuth()),
        );

        final ok = await container
            .read(authProvider.notifier)
            .signInWithBiometricToken();

        expect(ok, isFalse);
        expect(
          container.read(authProvider).failure,
          AuthFailure.biometricFailed,
        );
      });
    });

    test('disableBiometrics falls back to the stored uid', () async {
      channels.storage[_uidKey] = 'uid-1';
      final firestore = FakeFirebaseFirestore();
      final container = makeContainer(MockFirebaseAuth(), firestore: firestore);

      await container.read(authProvider.notifier).disableBiometrics();

      final doc = await firestore.collection('user').doc('uid-1').get();
      expect(doc.data()?['biometricToken'], isNull);
    });
  });

  test('signOut records an error when it throws', () async {
    final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
    whenCalling(Invocation.method(#signOut, [null]))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'fail'));
    final container = makeContainer(auth);

    await container.read(authProvider.notifier).signOut();

    expect(container.read(authProvider).failure, AuthFailure.signOutFailed);
  });

  group('deleteAccount', () {
    test('signs out and resets the state on success', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
      final container = makeContainer(auth);
      await container
          .read(authProvider.notifier)
          .signIn(email: 'a', password: 'b');

      await container.read(authProvider.notifier).deleteAccount();

      expect(container.read(authProvider).user, isNull);
    });

    test('rethrows and records the error on failure', () async {
      final user = buildUser(uid: 'del-fb');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      whenCalling(Invocation.method(#delete, []))
          .on(user)
          .thenThrow(FirebaseAuthException(code: 'requires-recent-login'));
      final container = makeContainer(auth);
      await container
          .read(authProvider.notifier)
          .signIn(email: 'a', password: 'b');

      await expectLater(
        container.read(authProvider.notifier).deleteAccount(),
        throwsA(AuthFailure.unknown),
      );
      expect(container.read(authProvider).failure, AuthFailure.unknown);
    });

    test('maps unexpected errors to the generic delete message', () async {
      final user = buildUser(uid: 'del-generic');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      whenCalling(Invocation.method(#delete, []))
          .on(user)
          .thenThrow(Exception('boom'));
      final container = makeContainer(auth);
      await container
          .read(authProvider.notifier)
          .signIn(email: 'a', password: 'b');

      await expectLater(
        container.read(authProvider.notifier).deleteAccount(),
        throwsA(isA<Exception>()),
      );
      expect(
        container.read(authProvider).failure,
        AuthFailure.deleteAccountFailed,
      );
    });
  });
}
