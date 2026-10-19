import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/domain/biometric_lock.dart';
import 'package:an_ki/features/auth/domain/guest_linked.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/auth/providers/fresh_sign_in_provider.dart';
import 'package:an_ki/features/auth/providers/guest_links.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import '../../../support/fake_providers.dart'
    show FakeAuthRepository, FakeBiometricService;
import '../../../support/platform_mocks.dart';

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

/// AuthRepository that links the anonymous account to Google without the
/// plugin, or fails with [error].
class _LinkingAuthRepository extends AuthRepository {
  _LinkingAuthRepository({this.error, MockFirebaseAuth? auth})
    : super(
        auth: auth ?? MockFirebaseAuth(),
        googleSignIn: GoogleSignIn.instance,
        firestore: FakeFirebaseFirestore(),
      );

  final Exception? error;

  /// Le compte Google choisi a été oublié (déconnexion du plugin).
  bool googleSignedOut = false;

  @override
  Future<User?> linkCurrentUserWithGoogle() async {
    if (error case final error?) throw error;
    return MockUser(uid: 'uid-1');
  }

  @override
  Future<void> signOutGoogle() async => googleSignedOut = true;
}

const _reason = 'Empreinte ?';
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

  /// Conteneur sur le vrai dépôt (Firebase simulé) et le vrai service
  /// biométrique (canaux simulés). On écoute l'accès et l'uid : Riverpod met
  /// en pause un provider sans écouteur.
  ProviderContainer makeContainer(
    MockFirebaseAuth auth, {
    FakeFirebaseFirestore? firestore,
    AuthRepository? repository,
  }) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
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
    container.listen(authAccessProvider, (_, _) {});
    container.listen(currentUidProvider, (_, _) {});
    return container;
  }

  AuthController controllerOf(ProviderContainer container) =>
      container.read(authControllerProvider.notifier);

  Object? failureOf(ProviderContainer container) =>
      container.read(authControllerProvider).error;

  /// Laisse arriver la session Firebase et la lecture du verrou biométrique.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('email/password', () {
    test('signIn opens the session', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser());
      final container = makeContainer(auth);

      final ok = await controllerOf(container)
          .signIn(email: 'test@example.com', password: 'pwd');
      await settle();

      expect(ok, isTrue);
      expect(container.read(currentUidProvider), 'uid-1');
      expect(container.read(authAccessProvider), AuthAccess.granted);
      expect(container.read(authControllerProvider), isA<AsyncData<void>>());
      // Ouverte ici : l'agenda du compte arrive sur cet appareil.
      expect(container.read(freshSignInProvider), 'uid-1');
    });

    test('signIn maps FirebaseAuthException codes to failures', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser());
      whenCalling(Invocation.method(#signInWithEmailAndPassword, []))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));
      final container = makeContainer(auth);

      final ok = await controllerOf(container)
          .signIn(email: 'test@example.com', password: 'bad');

      expect(ok, isFalse);
      expect(failureOf(container), AuthFailure.wrongPassword);
      expect(container.read(freshSignInProvider), isNull);
    });

    test('signIn maps unexpected errors to a generic failure', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser());
      whenCalling(Invocation.method(#signInWithEmailAndPassword, []))
          .on(auth)
          .thenThrow(Exception('network'));
      final container = makeContainer(auth);

      final ok = await controllerOf(container)
          .signIn(email: 'x', password: 'y');

      expect(ok, isFalse);
      expect(failureOf(container), AuthFailure.signInFailed);
    });

    test('signUp opens the session', () async {
      final auth = MockFirebaseAuth();
      final container = makeContainer(auth);

      final ok = await controllerOf(container).signUp(
        email: 'new@example.com',
        password: 'pwd',
        name: 'New',
        surname: 'User',
      );
      await settle();

      expect(ok, isTrue);
      expect(container.read(currentUidProvider), isNotNull);
    });

    test('signUp maps the weak-password code', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, []))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'weak-password'));
      final container = makeContainer(auth);

      final ok = await controllerOf(container)
          .signUp(email: 'x', password: 'y', name: 'N', surname: 'S');

      expect(ok, isFalse);
      expect(failureOf(container), AuthFailure.weakPassword);
    });

    test('signUp maps unexpected errors to the registration failure', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, []))
          .on(auth)
          .thenThrow(Exception('boom'));
      final container = makeContainer(auth);

      final ok = await controllerOf(container)
          .signUp(email: 'x', password: 'y', name: 'N', surname: 'S');

      expect(ok, isFalse);
      expect(failureOf(container), AuthFailure.signUpFailed);
    });

    test('a new operation clears the previous failure', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser(anonymous: true));
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));
      final container = makeContainer(auth);
      final controller = controllerOf(container);
      await controller.signIn(email: 'a', password: 'bad');
      expect(failureOf(container), AuthFailure.wrongPassword);

      await controller.signInAnonymously();

      expect(container.read(authControllerProvider), isA<AsyncData<void>>());
    });

    test('maps the documented Firebase codes to failures', () async {
      Future<Object?> failureFor(String code) async {
        final auth = MockFirebaseAuth(mockUser: buildUser());
        whenCalling(Invocation.method(#signInWithEmailAndPassword, []))
            .on(auth)
            .thenThrow(FirebaseAuthException(code: code));
        final container = makeContainer(auth);
        await controllerOf(container).signIn(email: 'a', password: 'b');
        return failureOf(container);
      }

      expect(await failureFor('invalid-email'), AuthFailure.invalidEmail);
      expect(await failureFor('user-not-found'), AuthFailure.userNotFound);
      expect(
        await failureFor('email-already-in-use'),
        AuthFailure.emailAlreadyInUse,
      );
      expect(await failureFor('something-else'), AuthFailure.unknown);
    });

    test('ignores a second call while one is running', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser());
      final controller = controllerOf(makeContainer(auth));

      final first = controller.signIn(email: 'a', password: 'b');
      final second = await controller.signIn(email: 'a', password: 'b');

      expect(second, isFalse);
      expect(await first, isTrue);
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
      final ok = await controllerOf(container).signInWithGoogle();
      expect(ok, isFalse);
      return container;
    }

    test('a cancelled Google sign-in is not reported as a failure', () async {
      final container = await signInFailingWith(
        GoogleSignInExceptionCode.canceled,
      );

      expect(container.read(authControllerProvider), isA<AsyncData<void>>());
    });

    test('a Google plugin error is reported', () async {
      final container = await signInFailingWith(
        GoogleSignInExceptionCode.unknownError,
      );

      expect(failureOf(container), AuthFailure.googleSignInFailed);
    });
  });

  group('anonymous', () {
    test('signInAnonymously opens a session', () async {
      final auth = MockFirebaseAuth(mockUser: buildUser(anonymous: true));
      final container = makeContainer(auth);

      final ok = await controllerOf(container).signInAnonymously();
      await settle();

      expect(ok, isTrue);
      expect(container.read(authUserProvider).value?.isAnonymous, isTrue);
    });

    test('signInAnonymously reports failures', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInAnonymously, []))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'operation-not-allowed'));
      final container = makeContainer(auth);

      final ok = await controllerOf(container).signInAnonymously();

      expect(ok, isFalse);
      expect(failureOf(container), AuthFailure.unknown);
    });
  });

  group('startup', () {
    test('a restored session opens the app without biometrics', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
      final container = makeContainer(auth);
      await settle();

      expect(container.read(authAccessProvider), AuthAccess.granted);
      expect(container.read(currentUidProvider), 'uid-1');
      // Restaurée, pas ouverte ici : rien de neuf sur cet appareil.
      expect(container.read(freshSignInProvider), isNull);
    });

    test(
      'a restored session stays locked when biometrics are set up',
      () async {
        channels.storage[_tokenKey] = 'tok';
        channels.storage[_uidKey] = 'uid-1';
        final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
        final container = makeContainer(auth);
        await settle();

        // Verrouillée, l'app garde la session : les données suivent derrière.
        expect(container.read(authAccessProvider), AuthAccess.locked);
        expect(container.read(currentUidProvider), 'uid-1');
      },
    );
  });

  group('linking an anonymous account to Google', () {
    late ProviderContainer container;

    Future<(bool, Object?)> link(_LinkingAuthRepository repository) async {
      container = makeContainer(MockFirebaseAuth(), repository: repository);
      final ok = await controllerOf(container).linkWithGoogle();
      return (ok, failureOf(container));
    }

    test('succeeds and records the link with the Google name', () async {
      // La session du dépôt est déjà celle du compte lié.
      final repository = _LinkingAuthRepository(
        auth: MockFirebaseAuth(signedIn: true, mockUser: buildUser()),
      );

      expect(await link(repository), (true, null));
      expect(
        container.read(guestLinksProvider),
        const GuestLinked(uid: 'uid-1', displayName: 'Test User'),
      );
      expect(repository.googleSignedOut, isFalse);
    });

    test('stays silent when the user cancels', () async {
      final repository = _LinkingAuthRepository(
        error: const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        ),
      );

      expect(await link(repository), (false, null));
      expect(container.read(guestLinksProvider), isNull);
    });

    test('reports a plugin error', () async {
      final repository = _LinkingAuthRepository(
        error: const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
        ),
      );

      expect(await link(repository), (false, AuthFailure.googleSignInFailed));
    });

    test(
      'reports a Google account already used by AnKi, and forgets it',
      () async {
        final repository = _LinkingAuthRepository(
          error: AuthFailure.credentialAlreadyInUse,
        );

        expect(await link(repository), (
          false,
          AuthFailure.credentialAlreadyInUse,
        ));
        // Un nouvel essai repropose tous les comptes Google.
        expect(repository.googleSignedOut, isTrue);
        expect(container.read(guestLinksProvider), isNull);
      },
    );

    test('reports a Firebase refusal', () async {
      final repository = _LinkingAuthRepository(
        error: AuthFailure.emailAlreadyInUse,
      );

      expect(await link(repository), (false, AuthFailure.emailAlreadyInUse));
    });
  });

  group('signOut', () {
    test('a full sign-out closes the Firebase session', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
      final container = makeContainer(auth);
      await controllerOf(container).signIn(email: 'a', password: 'b');

      await controllerOf(container).signOut();
      await settle();

      expect(auth.currentUser, isNull);
      expect(container.read(currentUidProvider), isNull);
      expect(container.read(authAccessProvider), AuthAccess.signedOut);
    });

    test('with biometrics, signing out only locks the app', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
      final container = makeContainer(auth);
      await settle();
      await controllerOf(container).enableBiometrics();

      await controllerOf(container).signOut();
      await settle();

      expect(auth.currentUser, isNotNull);
      expect(container.read(currentUidProvider), 'uid-1');
      expect(container.read(authAccessProvider), AuthAccess.locked);
    });

    test('closes the session when the fingerprint is unavailable', () async {
      // Jeton resté sur l'appareil, mais plus aucune empreinte enregistrée :
      // le verrou est désactivé, la déconnexion doit fermer la session.
      channels.storage[_tokenKey] = 'tok';
      channels.storage[_uidKey] = 'uid-1';
      channels.availableBiometrics = const [];
      final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
      final container = makeContainer(auth);
      await settle();
      expect(container.read(authAccessProvider), AuthAccess.granted);

      await controllerOf(container).signOut();
      await settle();

      expect(auth.currentUser, isNull);
      expect(container.read(authAccessProvider), AuthAccess.signedOut);
    });

    test('records a failure when it throws', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
      whenCalling(Invocation.method(#signOut, [null]))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'fail'));
      final container = makeContainer(auth);

      final ok = await controllerOf(container).signOut();

      expect(ok, isFalse);
      expect(failureOf(container), AuthFailure.signOutFailed);
    });
  });

  group('signing in over a stored fingerprint', () {
    Future<(ProviderContainer, MockFirebaseAuth)> signInAs(
      String fingerprintUid,
    ) async {
      channels.storage[_tokenKey] = 'tok';
      channels.storage[_uidKey] = fingerprintUid;
      final auth = MockFirebaseAuth(mockUser: buildUser());
      final container = makeContainer(auth);
      await settle();
      await controllerOf(container).signIn(email: 'a', password: 'b');
      await settle();
      expect(container.read(authAccessProvider), AuthAccess.granted);
      return (container, auth);
    }

    test('the account of the fingerprint keeps it', () async {
      final (container, _) = await signInAs('uid-1');

      expect(
        container.read(biometricLockProvider).value,
        const BiometricLock(enabled: true, unlocked: true),
      );
      expect(channels.storage[_tokenKey], 'tok');
    });

    test('another account forgets it, and really signs out', () async {
      final (container, auth) = await signInAs('uid-2');

      expect(
        container.read(biometricLockProvider).value,
        BiometricLock.disabled,
      );
      expect(channels.storage[_tokenKey], isNull);

      await controllerOf(container).signOut();
      await settle();

      expect(auth.currentUser, isNull);
      expect(container.read(authAccessProvider), AuthAccess.signedOut);
    });
  });

  group('biometrics', () {
    test('enableBiometrics stores a token and enables the lock', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
      final firestore = FakeFirebaseFirestore();
      final container = makeContainer(auth, firestore: firestore);
      await settle();

      final ok = await controllerOf(container).enableBiometrics();

      expect(ok, isTrue);
      expect(
        container.read(biometricLockProvider).value,
        const BiometricLock(enabled: true, unlocked: true),
      );
      expect(channels.storage[_tokenKey], isNotNull);
      final doc = await firestore.collection('user').doc('uid-1').get();
      expect(doc.data()?['biometricToken'], isNotNull);
    });

    test('enableBiometrics is a no-op without a signed-in user', () async {
      final container = makeContainer(MockFirebaseAuth());

      final ok = await controllerOf(container).enableBiometrics();

      expect(ok, isFalse);
      expect(channels.storage[_tokenKey], isNull);
    });

    test('disableBiometrics clears the profile and the device', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
      final firestore = FakeFirebaseFirestore();
      final container = makeContainer(auth, firestore: firestore);
      await settle();
      await controllerOf(container).enableBiometrics();

      await controllerOf(container).disableBiometrics();

      expect(container.read(biometricLockProvider).value?.enabled, isFalse);
      expect(channels.storage[_tokenKey], isNull);
      final doc = await firestore.collection('user').doc('uid-1').get();
      expect(doc.data()?['biometricToken'], isNull);
    });

    test(
      'disableBiometrics without a session forgets the device token',
      () async {
        channels.storage[_tokenKey] = 'tok';
        channels.storage[_uidKey] = 'uid-1';
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('user').doc('uid-1').set({
          'biometricToken': 'tok',
        });
        final container = makeContainer(
          MockFirebaseAuth(),
          firestore: firestore,
        );

        final ok = await controllerOf(container).disableBiometrics();

        expect(ok, isTrue);
        expect(channels.storage[_tokenKey], isNull);
        // Seul le compte connecté écrit son profil.
        final doc = await firestore.collection('user').doc('uid-1').get();
        expect(doc.data()?['biometricToken'], 'tok');
      },
    );

    group('unlockWithBiometrics', () {
      /// Session `uid-1` restaurée, verrouillée par l'empreinte : l'appareil
      /// garde le jeton `tok` de [fingerprintUid], que son profil connaît,
      /// sauf [revoked] (retiré, ou remplacé depuis un autre appareil).
      Future<(ProviderContainer, MockFirebaseAuth)> lockedSession({
        String fingerprintUid = 'uid-1',
        bool revoked = false,
      }) async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('user').doc(fingerprintUid).set({
          'biometricToken': revoked ? 'other-device' : 'tok',
        });
        channels.storage[_tokenKey] = 'tok';
        channels.storage[_uidKey] = fingerprintUid;
        final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
        final container = makeContainer(auth, firestore: firestore);
        await settle();
        expect(container.read(authAccessProvider), AuthAccess.locked);
        return (container, auth);
      }

      /// Déverrouillage refusé : session fermée, empreinte oubliée, et un
      /// message qui invite à se reconnecter.
      Future<void> expectSignedOut(
        ProviderContainer container,
        MockFirebaseAuth auth,
      ) async {
        final ok = await controllerOf(container)
            .unlockWithBiometrics(reason: _reason);
        await settle();

        expect(ok, isFalse);
        expect(failureOf(container), AuthFailure.biometricRevoked);
        expect(auth.currentUser, isNull);
        expect(channels.storage[_tokenKey], isNull);
        expect(container.read(authAccessProvider), AuthAccess.signedOut);
      }

      test('opens the locked session of its account', () async {
        final (container, _) = await lockedSession();

        final ok = await controllerOf(container)
            .unlockWithBiometrics(reason: _reason);

        expect(ok, isTrue);
        expect(container.read(authAccessProvider), AuthAccess.granted);
        expect(container.read(currentUidProvider), 'uid-1');
      });

      test('never opens the app without a Firebase session', () async {
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
        await settle();

        final ok = await controllerOf(container)
            .unlockWithBiometrics(reason: _reason);

        expect(ok, isFalse);
        expect(container.read(currentUidProvider), isNull);
        expect(container.read(authAccessProvider), AuthAccess.signedOut);
        expect(channels.storage[_tokenKey], 'tok');
      });

      test('stays locked when the fingerprint is rejected', () async {
        final (container, _) = await lockedSession();
        channels.authenticateResult = false;

        final ok = await controllerOf(container)
            .unlockWithBiometrics(reason: _reason);

        expect(ok, isFalse);
        expect(failureOf(container), isNull);
        expect(container.read(authAccessProvider), AuthAccess.locked);
      });

      test('signs out when the token was revoked', () async {
        final (container, auth) = await lockedSession(revoked: true);

        await expectSignedOut(container, auth);
      });

      test('signs out with the token of another account', () async {
        // Jeton valide, mais celui de `uid-2` : il n'ouvre pas `uid-1`.
        final (container, auth) = await lockedSession(fingerprintUid: 'uid-2');

        await expectSignedOut(container, auth);
      });

      test('signs out when the device lost its token', () async {
        final (container, auth) = await lockedSession();
        channels.storage.clear();

        await expectSignedOut(container, auth);
      });

      test('stays locked when the lookup throws', () async {
        channels.storage[_tokenKey] = 'tok';
        channels.storage[_uidKey] = 'uid-1';
        final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
        final container = makeContainer(
          auth,
          repository: _ThrowingAuthRepository(auth),
        );
        await settle();

        final ok = await controllerOf(container)
            .unlockWithBiometrics(reason: _reason);

        expect(ok, isFalse);
        expect(failureOf(container), AuthFailure.biometricFailed);
        // Échec passager (hors ligne sans cache) : la session reste,
        // verrouillée, sans déconnexion.
        expect(auth.currentUser, isNotNull);
        expect(container.read(authAccessProvider), AuthAccess.locked);
      });
    });
  });

  group('deleteAccount', () {
    test('closes the session on success', () async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: buildUser());
      final container = makeContainer(auth);
      await controllerOf(container).signIn(email: 'a', password: 'b');

      final ok = await controllerOf(container).deleteAccount();
      await settle();

      expect(ok, isTrue);
      expect(auth.currentUser, isNull);
      expect(container.read(authAccessProvider), AuthAccess.signedOut);
    });

    test('with the fingerprint on, forgets the device token', () async {
      // Profil déjà effacé par les réglages, session fermée : plus rien à
      // écrire dans Firestore, seul l'appareil garde son jeton.
      final repository = FakeAuthRepository(user: buildUser())
        ..biometricTokens['uid-1'] = 'tok';
      final biometrics = FakeBiometricService(
        available: true,
        token: 'tok',
        userId: 'uid-1',
      );
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          biometricServiceProvider.overrideWithValue(biometrics),
        ],
      );
      container.listen(authAccessProvider, (_, _) {});
      await settle();

      final ok = await controllerOf(container).deleteAccount();

      expect(ok, isTrue);
      expect(biometrics.token, isNull);
      expect(
        container.read(biometricLockProvider).value,
        BiometricLock.disabled,
      );
    });

    test('reports a Firebase refusal', () async {
      final user = buildUser(uid: 'del-fb');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      whenCalling(Invocation.method(#delete, []))
          .on(user)
          .thenThrow(FirebaseAuthException(code: 'requires-recent-login'));
      final container = makeContainer(auth);
      await controllerOf(container).signIn(email: 'a', password: 'b');

      final ok = await controllerOf(container).deleteAccount();

      expect(ok, isFalse);
      expect(failureOf(container), AuthFailure.unknown);
    });

    test('maps unexpected errors to the deletion failure', () async {
      final user = buildUser(uid: 'del-generic');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      whenCalling(Invocation.method(#delete, []))
          .on(user)
          .thenThrow(Exception('boom'));
      final container = makeContainer(auth);
      await controllerOf(container).signIn(email: 'a', password: 'b');

      final ok = await controllerOf(container).deleteAccount();

      expect(ok, isFalse);
      expect(failureOf(container), AuthFailure.deleteAccountFailed);
    });
  });
}
