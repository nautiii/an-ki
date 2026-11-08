import 'dart:async';

import 'package:an_ki/app/bootstrap/app_initializer.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/domain/guest_linked.dart';
import 'package:an_ki/features/auth/providers/guest_links.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/auth/providers/sign_up_names_provider.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/birthday/screens/person_screen.dart';
import 'package:an_ki/features/settings/providers/account_deletion.dart';
import 'package:an_ki/features/settings/screens/settings_screen.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as fam;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';
import '../../support/test_harness.dart';

/// Dépôt dont le profil n'arrive que lorsque le test le décide ; il note les
/// créations demandées, dont les [failures] premières échouent.
class _PendingUserRepository extends FakeUserRepository {
  _PendingUserRepository({this.failures = 0});

  final profile = StreamController<UserProfile?>();
  final created = <UserProfile>[];
  int failures;

  @override
  Stream<UserProfile?> watchUser(String uid) => profile.stream;

  @override
  Future<UserProfile> createUser(UserProfile user) async {
    created.add(user);
    if (failures > 0) {
      failures--;
      throw Exception('offline');
    }
    return user;
  }

  Future<void> close() => profile.close();
}

const _profile = UserProfile(
  id: 'u1',
  name: 'Camille',
  surname: 'Durand',
  locale: 'fr',
);

void main() {
  Future<void> pumpInitializer(
    WidgetTester tester, {
    required FakeUserRepository users,
    String? displayName = 'Léa Martin',
    bool anonymous = false,
    SignUpNames? typedNames,
    Completer<void>? accountDeletion,
  }) => tester.pumpHarness(
    const AppInitializer(child: _Child()),
    overrides: [
      authUserProvider.overrideWithValue(
        AsyncData(
          fam.MockUser(
            uid: 'u1',
            isAnonymous: anonymous,
            displayName: displayName,
          ),
        ),
      ),
      biometricServiceProvider.overrideWithValue(FakeBiometricService()),
      userRepositoryProvider.overrideWithValue(users),
      birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
      if (typedNames != null)
        signUpNamesProvider.overrideWithBuild((ref, notifier) => typedNames),
      // Suppression du compte en cours, jusqu'à ce que le test la termine.
      if (accountDeletion != null)
        accountDeletionProvider.overrideWithBuild(
          (ref, notifier) => accountDeletion.future,
        ),
    ],
  );

  testWidgets('waits for the first profile, then shows the app', (
    tester,
  ) async {
    final users = _PendingUserRepository();
    addTearDown(users.close);
    await pumpInitializer(tester, users: users);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    users.profile.add(_profile);
    await tester.pumpAndSettle();

    expect(find.text('Child ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('creates a nameless profile for a guest', (tester) async {
    final users = RecordingUserRepository();
    await pumpInitializer(
      tester,
      users: users,
      displayName: '',
      anonymous: true,
    );
    await tester.pumpAndSettle();

    // Pas de « Invité » écrit dans les données : l'accueil salue sans nom.
    expect(users.created.single.name, isEmpty);
    expect(users.created.single.surname, isEmpty);
    expect(users.created.single.id, 'u1');
    expect(find.text('Child ready'), findsOneWidget);
  });

  testWidgets('splits the Google display name', (tester) async {
    final users = RecordingUserRepository();
    await pumpInitializer(tester, users: users);
    await tester.pumpAndSettle();

    expect(users.created.single.name, 'Léa');
    expect(users.created.single.surname, 'Martin');
  });

  testWidgets('leaves the language to the phone in a new profile', (
    tester,
  ) async {
    final users = RecordingUserRepository();
    await pumpInitializer(tester, users: users);
    await tester.pumpAndSettle();

    expect(users.created.single.locale, isNull);
  });

  testWidgets('keeps the names typed at sign-up, then forgets them', (
    tester,
  ) async {
    final users = RecordingUserRepository();
    await pumpInitializer(
      tester,
      users: users,
      displayName: 'Jean Pierre Dupont',
      typedNames: (name: 'Jean Pierre', surname: 'Dupont'),
    );
    await tester.pumpAndSettle();

    expect(users.created.single.name, 'Jean Pierre');
    expect(users.created.single.surname, 'Dupont');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppInitializer)),
    );
    expect(container.read(signUpNamesProvider), isNull);
  });

  testWidgets('never recreates the profile an account deletion erased', (
    tester,
  ) async {
    final users = RecordingUserRepository();
    final deletion = Completer<void>();
    await pumpInitializer(tester, users: users, accountDeletion: deletion);
    await tester.pump();
    await tester.pump();

    expect(users.created, isEmpty);

    // Échouée après l'effacement, la suppression laisse un compte : son
    // profil revient.
    deletion.completeError(Exception('delete failed'));
    await tester.pump();
    await tester.pump();

    expect(users.created.single.id, 'u1');
  });

  testWidgets('never creates a profile that already exists', (tester) async {
    final users = RecordingUserRepository(stored: _profile);
    await pumpInitializer(tester, users: users);
    await tester.pumpAndSettle();

    expect(users.created, isEmpty);
    expect(find.text('Child ready'), findsOneWidget);
  });

  testWidgets('never creates a profile that arrives just after an empty read', (
    tester,
  ) async {
    final users = _PendingUserRepository();
    addTearDown(users.close);
    await pumpInitializer(tester, users: users);

    // Le cache vide d'abord, puis le profil du serveur, avant la création.
    users.profile
      ..add(null)
      ..add(_profile);
    await tester.pumpAndSettle();

    expect(users.created, isEmpty);
  });

  testWidgets('tries the creation again at the next empty profile', (
    tester,
  ) async {
    final users = _PendingUserRepository(failures: 1);
    addTearDown(users.close);
    await pumpInitializer(tester, users: users);
    users.profile.add(null);
    await tester.pumpAndSettle();
    expect(users.created, hasLength(1));

    // Une lecture refusée, puis toujours pas de profil : un nouvel essai.
    users.profile.addError(Exception('unavailable'));
    await tester.pumpAndSettle();
    users.profile.add(null);
    await tester.pumpAndSettle();

    expect(users.created, hasLength(2));
  });

  group('a guest linked to Google', () {
    /// Profil d'invité : sans nom (ou « Invité », des anciennes versions),
    /// avec un pseudo choisi.
    UserProfile guestProfile({String name = ''}) => UserProfile(
      id: 'u1',
      name: name,
      surname: '',
      pseudo: 'Cam',
      locale: 'fr',
    );

    /// Lie l'invité au compte Google nommé [displayName].
    Future<void> link(
      WidgetTester tester,
      RecordingUserRepository users, {
      required String displayName,
    }) async {
      await pumpInitializer(tester, users: users, anonymous: true);
      await tester.pumpAndSettle();
      ProviderScope.containerOf(tester.element(find.byType(AppInitializer)))
          .read(guestLinksProvider.notifier)
          .record(GuestLinked(uid: 'u1', displayName: displayName));
      await tester.pumpAndSettle();
    }

    testWidgets('takes the names of the Google account, keeps the pseudo', (
      tester,
    ) async {
      final users = RecordingUserRepository(stored: guestProfile());

      await link(tester, users, displayName: 'Camille Martin');

      expect(
        users.stored,
        const UserProfile(
          id: 'u1',
          name: 'Camille',
          surname: 'Martin',
          pseudo: 'Cam',
          locale: 'fr',
        ),
      );
    });

    testWidgets('replaces the « Invité » of earlier versions', (tester) async {
      final users = RecordingUserRepository(
        stored: guestProfile(name: 'Invité'),
      );

      await link(tester, users, displayName: 'Camille Martin');

      expect(users.stored?.name, 'Camille');
    });

    testWidgets('leaves the profile alone without a Google name', (
      tester,
    ) async {
      final users = RecordingUserRepository(stored: guestProfile());

      await link(tester, users, displayName: '');

      expect(users.updated, isEmpty);
      expect(users.stored, guestProfile());
    });

    testWidgets('keeps the profile as it was when its names cannot be '
        'written', (tester) async {
      final users = RecordingUserRepository(
        stored: guestProfile(),
        failure: Exception('offline'),
      );

      await link(tester, users, displayName: 'Camille Martin');

      expect(users.updated, isEmpty);
      expect(users.stored, guestProfile());
    });
  });

  group('notification taps', () {
    const lea = Birthday(
      id: 'lea',
      name: 'Léa',
      surname: 'Martin',
      date: BirthDate(month: 3, day: 12),
    );
    const message = 'Bon anniversaire Léa ! 🎂';
    const wishTap = NotificationTap(
      payload: 'lea',
      actionId: NotificationActions.wish,
    );

    /// L'app entière, connectée, avec le carnet de Léa.
    Future<void> pumpSignedInApp(
      WidgetTester tester, {
      required SilentNotificationService notifications,
      required FakeShareService share,
    }) async {
      await tester.pumpApp(
        auth: FakeAuthRepository(user: MockUser()),
        birthdays: const [lea],
        notifications: notifications,
        share: share,
      );
      await tester.settleApp();
    }

    testWidgets('« Souhaiter » goes home and opens the share sheet', (
      tester,
    ) async {
      final notifications = SilentNotificationService();
      final share = FakeShareService();
      await mockNetworkImages(() async {
        await pumpSignedInApp(
          tester,
          notifications: notifications,
          share: share,
        );
        // Les réglages s'ouvrent par-dessus l'onglet, comme dans l'app.
        unawaited(tester.appRouter.push(AppRoutes.settings));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);

        notifications.tap(wishTap);
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(share.shared, [message]);
        expect(find.text('Léa Martin a reçu vos vœux'), findsOneWidget);
      });
    });

    testWidgets('wishes from the button that launched the app', (tester) async {
      final share = FakeShareService();
      await mockNetworkImages(() async {
        await pumpSignedInApp(
          tester,
          notifications: SilentNotificationService(launch: wishTap),
          share: share,
        );

        expect(share.shared, [message]);
      });
    });

    testWidgets('a tap on the notification itself opens the person page', (
      tester,
    ) async {
      final notifications = SilentNotificationService();
      final share = FakeShareService();
      await mockNetworkImages(() async {
        await pumpSignedInApp(
          tester,
          notifications: notifications,
          share: share,
        );

        notifications.tap(const NotificationTap(payload: 'lea'));
        await tester.pumpAndSettle();

        expect(find.byType(PersonScreen), findsOneWidget);
        expect(find.text('Léa Martin'), findsOneWidget);
        expect(share.shared, isEmpty);
        // Retour : l'accueil, resté dessous.
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
      });
    });

    testWidgets('never stacks the page of the person already open', (
      tester,
    ) async {
      final notifications = SilentNotificationService();
      await mockNetworkImages(() async {
        await pumpSignedInApp(
          tester,
          notifications: notifications,
          share: FakeShareService(),
        );

        notifications.tap(const NotificationTap(payload: 'lea'));
        await tester.pumpAndSettle();
        notifications.tap(const NotificationTap(payload: 'lea'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(PersonScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
      });
    });

    testWidgets('opens the person page from the tap that launched the app', (
      tester,
    ) async {
      await mockNetworkImages(() async {
        await pumpSignedInApp(
          tester,
          notifications: SilentNotificationService(
            launch: const NotificationTap(payload: 'lea'),
          ),
          share: FakeShareService(),
        );

        expect(find.byType(PersonScreen), findsOneWidget);
      });
    });

    testWidgets('ignores a tap naming no birthday, or one deleted since the '
        'reminder', (tester) async {
      final notifications = SilentNotificationService();
      final share = FakeShareService();
      await mockNetworkImages(() async {
        await pumpSignedInApp(
          tester,
          notifications: notifications,
          share: share,
        );

        notifications
          ..tap(const NotificationTap(payload: null))
          ..tap(
            const NotificationTap(
              payload: 'gone',
              actionId: NotificationActions.wish,
            ),
          );
        await tester.pumpAndSettle();

        expect(share.shared, isEmpty);
        expect(find.byType(PersonScreen), findsNothing);
      });
    });
  });
}

class _Child extends StatelessWidget {
  const _Child();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Child ready')));
  }
}
