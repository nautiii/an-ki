import 'package:an_ki/features/auth/data/repositories/auth_repository.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import '../../support/platform_mocks.dart';

/// AuthRepository whose biometric lookup always throws, to drive the error path.
class _ThrowingAuthRepository extends AuthRepository {
  _ThrowingAuthRepository(MockFirebaseAuth auth)
    : super(auth: auth, firestore: FakeFirebaseFirestore());

  @override
  Future<bool> isBiometricTokenValid(String uid, String token) async =>
      throw Exception('lookup failed');
}

const _tokenKey = 'biometric_auth_token';
const _uidKey = 'biometric_user_id';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;
  late FakeBiometricChannels channels;

  setUpAll(() async {
    GoogleSignInPlatform.instance = FakeGoogleSignInPlatform();
    await GoogleSignIn.instance.initialize();
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
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
          .signIn(email: 'test@example.com', password: 'pwd', l10n: l10n);

      expect(ok, isTrue);
      expect(container.read(authProvider).user?.uid, 'uid-1');
    });

    test('signIn maps FirebaseAuthException codes to messages', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser());
      whenCalling(
        Invocation.method(#signInWithEmailAndPassword, []),
      ).on(auth).thenThrow(FirebaseAuthException(code: 'wrong-password'));
      final container = makeContainer(auth);

      final ok = await container
          .read(authProvider.notifier)
          .signIn(email: 'test@example.com', password: 'bad', l10n: l10n);

      expect(ok, isFalse);
      expect(
        container.read(authProvider).errorMessage,
        l10n.errorWrongPassword,
      );
    });

    test('signIn maps unexpected errors to a generic message', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser());
      whenCalling(
        Invocation.method(#signInWithEmailAndPassword, []),
      ).on(auth).thenThrow(Exception('network'));
      final container = makeContainer(auth);

      final ok = await container
          .read(authProvider.notifier)
          .signIn(email: 'x', password: 'y', l10n: l10n);

      expect(ok, isFalse);
      expect(container.read(authProvider).errorMessage, l10n.connectionError);
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
            l10n: l10n,
          );

      expect(ok, isTrue);
      expect(container.read(authProvider).user, isNotNull);
    });

    test('signUp maps the weak-password code', () async {
      final auth = MockFirebaseAuth();
      whenCalling(
        Invocation.method(#createUserWithEmailAndPassword, []),
      ).on(auth).thenThrow(FirebaseAuthException(code: 'weak-password'));
      final container = makeContainer(auth);

      final ok = await container
          .read(authProvider.notifier)
          .signUp(
            email: 'x',
            password: 'y',
            name: 'N',
            surname: 'S',
            l10n: l10n,
          );

      expect(ok, isFalse);
      expect(container.read(authProvider).errorMessage, l10n.errorWeakPassword);
    });

    test('signUp maps unexpected errors to the registration message', () async {
      final auth = MockFirebaseAuth();
      whenCalling(
        Invocation.method(#createUserWithEmailAndPassword, []),
      ).on(auth).thenThrow(Exception('boom'));
      final container = makeContainer(auth);

      final ok = await container
          .read(authProvider.notifier)
          .signUp(
            email: 'x',
            password: 'y',
            name: 'N',
            surname: 'S',
            l10n: l10n,
          );

      expect(ok, isFalse);
      expect(container.read(authProvider).errorMessage, l10n.registrationError);
    });

    test('error code mapping covers the documented codes', () async {
      Future<String?> messageFor(String code) async {
        final auth = MockFirebaseAuth(mockUser: buildUser());
        whenCalling(
          Invocation.method(#signInWithEmailAndPassword, []),
        ).on(auth).thenThrow(FirebaseAuthException(code: code));
        final container = makeContainer(auth);
        await container
            .read(authProvider.notifier)
            .signIn(email: 'a', password: 'b', l10n: l10n);
        return container.read(authProvider).errorMessage;
      }

      expect(await messageFor('invalid-email'), l10n.errorInvalidEmail);
      expect(await messageFor('user-not-found'), l10n.errorUserNotFound);
      expect(
        await messageFor('email-already-in-use'),
        l10n.errorEmailAlreadyInUse,
      );
      expect(await messageFor('something-else'), l10n.errorUnknown);
    });
  });

  group('anonymous', () {
    test('signInAnonymously succeeds', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser(anonymous: true));
      final container = makeContainer(auth);

      final ok = await container
          .read(authProvider.notifier)
          .signInAnonymously(l10n);

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
          .signInAnonymously(l10n);

      expect(ok, isFalse);
      expect(container.read(authProvider).errorMessage, l10n.errorUnknown);
    });
  });

  group('signOut', () {
    test('a full sign-out clears the Firebase user', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
      final container = makeContainer(auth);
      await container
          .read(authProvider.notifier)
          .signIn(email: 'a', password: 'b', l10n: l10n);

      await container.read(authProvider.notifier).signOut(l10n);

      expect(container.read(authProvider).user, isNull);
    });

    test('a biometric lock keeps the Firebase session', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser());
      final container = makeContainer(auth);
      await container
          .read(authProvider.notifier)
          .signIn(email: 'a', password: 'b', l10n: l10n);
      channels.storage[_tokenKey] = 'tok'; // biometric configured

      await container.read(authProvider.notifier).signOut(l10n);

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
        final container = makeContainer(MockFirebaseAuth(), firestore: firestore);

        final ok = await container
            .read(authProvider.notifier)
            .signInWithBiometricToken(l10n);

        expect(ok, isTrue);
        expect(container.read(authProvider).isBiometricallyAuthenticated, true);
        expect(container.read(authProvider).biometricUid, 'uid-1');
      });

      test('fails when the biometric check is rejected', () async {
        channels.authenticateResult = false;
        final container = makeContainer(MockFirebaseAuth());

        final ok = await container
            .read(authProvider.notifier)
            .signInWithBiometricToken(l10n);

        expect(ok, isFalse);
      });

      test('fails when there is no stored token', () async {
        final container = makeContainer(MockFirebaseAuth());

        final ok = await container
            .read(authProvider.notifier)
            .signInWithBiometricToken(l10n);

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
            .signInWithBiometricToken(l10n);

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
            .signInWithBiometricToken(l10n);

        expect(ok, isFalse);
        expect(container.read(authProvider).errorMessage, l10n.biometricError);
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
    whenCalling(
      Invocation.method(#signOut, [null]),
    ).on(auth).thenThrow(FirebaseAuthException(code: 'fail'));
    final container = makeContainer(auth);

    await container.read(authProvider.notifier).signOut(l10n);

    expect(container.read(authProvider).errorMessage, l10n.errorSignOut);
  });

  group('deleteAccount', () {
    test('signs out and resets the state on success', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
      final container = makeContainer(auth);
      await container
          .read(authProvider.notifier)
          .signIn(email: 'a', password: 'b', l10n: l10n);

      await container.read(authProvider.notifier).deleteAccount(l10n);

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
          .signIn(email: 'a', password: 'b', l10n: l10n);

      await expectLater(
        container.read(authProvider.notifier).deleteAccount(l10n),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(container.read(authProvider).errorMessage, isNotNull);
    });

    test('maps unexpected errors to the generic delete message', () async {
      final user = buildUser(uid: 'del-generic');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      whenCalling(
        Invocation.method(#delete, []),
      ).on(user).thenThrow(Exception('boom'));
      final container = makeContainer(auth);
      await container
          .read(authProvider.notifier)
          .signIn(email: 'a', password: 'b', l10n: l10n);

      await expectLater(
        container.read(authProvider.notifier).deleteAccount(l10n),
        throwsA(isA<Exception>()),
      );
      expect(
        container.read(authProvider).errorMessage,
        l10n.deleteAccountError,
      );
    });
  });
}
