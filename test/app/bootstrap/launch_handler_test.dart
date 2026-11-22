import 'dart:async';

import 'package:an_ki/app/shell/main_shell.dart';
import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/wish_suggestions.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/birthday/screens/person_screen.dart';
import 'package:an_ki/features/birthday/widgets/wish_text.dart';
import 'package:an_ki/features/settings/screens/settings_screen.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';

void main() {
  group('notification taps', () {
    const lea = Birthday(
      id: 'lea',
      name: 'Léa',
      surname: 'Martin',
      date: BirthDate(month: 3, day: 12),
    );
    // Le jour J de Léa, 9 h : l'action de la notification J-0.
    final now = DateTime(2026, 3, 12, 9);
    final message = wishTexts(
      lookupAppLocalizations(const Locale('fr')),
      'Léa',
      lea.wishSuggestions(now),
    ).first;
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
        overrides: [clockProvider.overrideWithValue(() => now)],
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

    testWidgets('a wish that launched a locked app waits for the '
        'fingerprint', (tester) async {
      final share = FakeShareService();
      final biometrics = FakeBiometricService(
        available: true,
        token: 'tok',
        userId: 'fake-uid',
        authenticates: false,
      );
      await mockNetworkImages(() async {
        await tester.pumpApp(
          auth: FakeAuthRepository(user: MockUser())
            ..biometricTokens['fake-uid'] = 'tok',
          biometrics: biometrics,
          birthdays: const [lea],
          notifications: SilentNotificationService(launch: wishTap),
          share: share,
          overrides: [clockProvider.overrideWithValue(() => now)],
        );
        await tester.settleApp();
        expect(find.byType(MainShell), findsNothing);
        expect(share.shared, isEmpty);

        biometrics.authenticates = true;
        await tester.tap(find.text('Déverrouiller'));
        await tester.settleApp();

        expect(find.byType(HomeScreen), findsOneWidget);
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
