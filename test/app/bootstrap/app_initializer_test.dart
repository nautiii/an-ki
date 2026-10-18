import 'dart:async';

import 'package:an_ki/app/bootstrap/app_initializer.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/auth/providers/sign_up_names_provider.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
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

/// Dépôt dont le profil n'arrive que lorsque le test le décide.
class _PendingUserRepository extends FakeUserRepository {
  final profile = StreamController<UserProfile?>();

  @override
  Stream<UserProfile?> watchUser(String uid) => profile.stream;

  Future<void> close() => profile.close();
}

const _profile = UserProfile(
  id: 'u1',
  name: 'Camille',
  surname: 'Durand',
  isDark: false,
  locale: 'fr',
);

void main() {
  Future<void> pumpInitializer(
    WidgetTester tester, {
    required FakeUserRepository users,
    String? displayName = 'Léa Martin',
    bool anonymous = false,
    SignUpNames? typedNames,
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

  testWidgets('creates a guest profile for an anonymous account', (
    tester,
  ) async {
    final users = RecordingUserRepository();
    await pumpInitializer(
      tester,
      users: users,
      displayName: '',
      anonymous: true,
    );
    await tester.pumpAndSettle();

    expect(users.created.single.name, 'Invité');
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

  testWidgets('never creates a profile that already exists', (tester) async {
    final users = RecordingUserRepository(stored: _profile);
    await pumpInitializer(tester, users: users);
    await tester.pumpAndSettle();

    expect(users.created, isEmpty);
    expect(find.text('Child ready'), findsOneWidget);
  });

  group('notification taps', () {
    const lea = Birthday(
      id: 'lea',
      name: 'Léa',
      surname: 'Martin',
      date: BirthDate(month: 3, day: 12),
    );
    const message =
        'Joyeux anniversaire Léa ! 🎂 Je te souhaite une très belle '
        'journée.';
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
        expect(
          find.text('Anniversaire de Léa Martin souhaité'),
          findsOneWidget,
        );
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

    testWidgets('a tap on the notification itself only opens the app', (
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

        expect(share.shared, isEmpty);
      });
    });

    testWidgets('ignores a birthday deleted since the reminder', (
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

        notifications.tap(
          const NotificationTap(
            payload: 'gone',
            actionId: NotificationActions.wish,
          ),
        );
        await tester.pumpAndSettle();

        expect(share.shared, isEmpty);
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
