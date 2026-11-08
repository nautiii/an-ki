import 'dart:async';

import 'package:an_ki/app/modules/birthdays_module.dart';
import 'package:an_ki/app/modules/birthdays_settings_section.dart';
import 'package:an_ki/app/modules/books_module.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/app/router/app_router.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/domain/biometric_lock.dart';
import 'package:an_ki/features/auth/screens/auth_choice_screen.dart';
import 'package:an_ki/features/auth/screens/login_screen.dart';
import 'package:an_ki/features/auth/screens/signup_screen.dart';
import 'package:an_ki/features/auth/screens/welcome_screen.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/screens/birthday_search_screen.dart';
import 'package:an_ki/features/birthday/screens/contact_import_screen.dart';
import 'package:an_ki/features/birthday/screens/groups_screen.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/birthday/screens/person_screen.dart';
import 'package:an_ki/features/books/screens/book_scanner_screen.dart';
import 'package:an_ki/features/reminders/widgets/reminders_off_card.dart';
import 'package:an_ki/features/settings/screens/settings_screen.dart';
import 'package:an_ki/features/settings/widgets/guest_backup_card.dart';
import 'package:an_ki/features/settings/widgets/settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_harness.dart';
import '../../support/fake_mobile_scanner_platform.dart';
import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';
import '../../support/probe_module.dart';

void main() {
  group('accessRedirect', () {
    test('waits on the startup screen until the access is known', () {
      expect(accessRedirect(null, AppRoutes.birthdays), '/');
      expect(accessRedirect(null, AppRoutes.auth), '/');
      expect(accessRedirect(null, '/'), isNull);
    });

    test('keeps signed-out users on the welcome, sign-in pages above it', () {
      const signedOut = AuthAccess.signedOut;

      expect(accessRedirect(signedOut, '/'), AppRoutes.welcome);
      expect(accessRedirect(signedOut, AppRoutes.birthdays), AppRoutes.welcome);
      expect(accessRedirect(signedOut, AppRoutes.settings), AppRoutes.welcome);
      expect(accessRedirect(signedOut, '/authors'), AppRoutes.welcome);
      expect(accessRedirect(signedOut, AppRoutes.welcome), isNull);
      expect(accessRedirect(signedOut, AppRoutes.auth), isNull);
      expect(accessRedirect(signedOut, AppRoutes.login), isNull);
      expect(accessRedirect(signedOut, AppRoutes.signup), isNull);
    });

    test('keeps a locked app on the sign-in pages, never the welcome', () {
      const locked = AuthAccess.locked;

      expect(accessRedirect(locked, '/'), AppRoutes.auth);
      expect(accessRedirect(locked, AppRoutes.birthdays), AppRoutes.auth);
      expect(accessRedirect(locked, '/authors'), AppRoutes.auth);
      // « Commencer » y remplacerait la session du compte verrouillé.
      expect(accessRedirect(locked, AppRoutes.welcome), AppRoutes.auth);
      expect(accessRedirect(locked, AppRoutes.auth), isNull);
      expect(accessRedirect(locked, AppRoutes.login), isNull);
      expect(accessRedirect(locked, AppRoutes.signup), isNull);
    });

    test('sends a granted user to the app, never back to the sign-in', () {
      const granted = AuthAccess.granted;

      expect(accessRedirect(granted, '/'), AppRoutes.birthdays);
      expect(accessRedirect(granted, AppRoutes.welcome), AppRoutes.birthdays);
      expect(accessRedirect(granted, AppRoutes.auth), AppRoutes.birthdays);
      expect(accessRedirect(granted, AppRoutes.login), AppRoutes.birthdays);
      expect(accessRedirect(granted, AppRoutes.birthdays), isNull);
      expect(accessRedirect(granted, AppRoutes.scanner), isNull);
      expect(accessRedirect(granted, AppRoutes.settings), isNull);
    });
  });

  group('routes', () {
    setUp(FakeMobileScannerPlatform.install);

    testWidgets('each signed-in path opens its screen', (tester) async {
      await mockNetworkImages(() async {
        await tester.pumpApp(auth: FakeAuthRepository(user: MockUser()));
        await tester.settleApp();
        expect(find.byType(HomeScreen), findsOneWidget);
        // L'accueil reçoit la carte de sauvegarde de `settings`.
        final guestBackup = tester
            .widget<HomeScreen>(find.byType(HomeScreen))
            .guestBackup;
        expect(guestBackup?.call(3), isA<GuestBackupCard>());

        tester.appRouter.go(AppRoutes.scanner);
        await tester.pumpAndSettle();
        expect(find.byType(BookScannerScreen), findsOneWidget);

        unawaited(tester.appRouter.push(AppRoutes.search));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BirthdaySearchScreen>(find.byType(BirthdaySearchScreen))
              .initialCategoryId,
          isNull,
        );
        await tester.tap(find.byTooltip('Retour'));
        await tester.pumpAndSettle();

        // Ouverte depuis un groupe, la recherche le reçoit.
        unawaited(tester.appRouter.push(AppRoutes.searchInCategory('fam')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BirthdaySearchScreen>(find.byType(BirthdaySearchScreen))
              .initialCategoryId,
          'fam',
        );
        await tester.tap(find.byTooltip('Retour'));
        await tester.pumpAndSettle();
        expect(find.byType(BookScannerScreen), findsOneWidget);

        unawaited(tester.appRouter.push(AppRoutes.settings));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);

        // Les réglages s'ouvrent par-dessus l'onglet, qui reste en place.
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(BookScannerScreen), findsOneWidget);

        unawaited(tester.appRouter.push(AppRoutes.contactImport));
        await tester.pumpAndSettle();
        expect(find.byType(ContactImportScreen), findsOneWidget);
        await tester.tap(find.byType(CloseButton));
        await tester.pumpAndSettle();
        expect(find.byType(BookScannerScreen), findsOneWidget);

        unawaited(tester.appRouter.push(AppRoutes.groups));
        await tester.pumpAndSettle();
        expect(find.byType(GroupsScreen), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(BookScannerScreen), findsOneWidget);
      });
    });

    testWidgets('declares one tab branch per module, in registry order', (
      tester,
    ) async {
      final probe = probeModule();
      await mockNetworkImages(() async {
        await tester.pumpApp(
          auth: FakeAuthRepository(user: MockUser()),
          overrides: [
            appModulesProvider.overrideWithValue([
              birthdaysModule,
              booksModule,
              probe,
            ]),
          ],
        );
        await tester.settleApp();
      });

      final shell = tester.appRouter.configuration.routes
          .whereType<StatefulShellRoute>()
          .single;
      expect(
        [
          for (final branch in shell.branches)
            (branch.routes.first as GoRoute).path,
        ],
        [AppRoutes.birthdays, AppRoutes.scanner, probeRoot],
      );
    });

    testWidgets('the settings show the active modules sections, in order', (
      tester,
    ) async {
      final probe = probeModule(
        settingsSection: const SettingsSection(
          title: 'Section sonde',
          children: [ListTile(title: Text('Réglage sonde'))],
        ),
      );
      await mockNetworkImages(() async {
        await tester.pumpApp(
          auth: FakeAuthRepository(user: MockUser()),
          overrides: [
            appModulesProvider.overrideWithValue([
              birthdaysModule,
              booksModule,
              probe,
            ]),
          ],
        );
        await tester.settleApp();

        unawaited(tester.appRouter.push(AppRoutes.settings));
        await tester.pumpAndSettle();
      });

      final sections = tester
          .widget<SettingsScreen>(find.byType(SettingsScreen))
          .moduleSections;
      expect(sections, hasLength(2));
      expect(sections.first, isA<BirthdaysSettingsSection>());
      expect(find.text('Section sonde'), findsOneWidget);
    });

    testWidgets('an inactive module has no settings section', (tester) async {
      final probe = probeModule(
        settingsSection: const SettingsSection(
          title: 'Section sonde',
          children: [ListTile(title: Text('Réglage sonde'))],
        ),
      );
      await mockNetworkImages(() async {
        await tester.pumpApp(
          auth: FakeAuthRepository(user: MockUser()),
          overrides: [
            appModulesProvider.overrideWithValue([birthdaysModule, probe]),
            activeModulesProvider.overrideWithValue([birthdaysModule]),
          ],
        );
        await tester.settleApp();

        unawaited(tester.appRouter.push(AppRoutes.settings));
        await tester.pumpAndSettle();
      });

      expect(find.byType(BirthdaysSettingsSection), findsOneWidget);
      expect(find.text('Section sonde'), findsNothing);
    });

    testWidgets('a person path opens that person above the tab', (
      tester,
    ) async {
      const lea = Birthday(
        id: 'lea',
        name: 'Léa',
        surname: 'Martin',
        date: BirthDate(month: 3, day: 12),
      );
      await mockNetworkImages(() async {
        await tester.pumpApp(
          auth: FakeAuthRepository(user: MockUser()),
          birthdays: const [lea],
        );
        await tester.settleApp();

        unawaited(tester.appRouter.push(AppRoutes.person('lea')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<PersonScreen>(find.byType(PersonScreen)).birthdayId,
          'lea',
        );
        expect(find.text('Léa Martin'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
      });
    });

    testWidgets('the home says when reminders are off on this phone', (
      tester,
    ) async {
      final notifications = SilentNotificationService(
        access: NotificationAccess.denied,
      );
      await mockNetworkImages(() async {
        await tester.pumpApp(
          auth: FakeAuthRepository(user: MockUser()),
          birthdays: [
            Birthday(
              id: '1',
              name: 'Léa',
              surname: 'Martin',
              date: BirthDate.fromDate(DateTime(1990, 3, 12)),
            ),
          ],
          notifications: notifications,
        );
        await tester.settleApp();
      });

      // La carte elle-même est testée à part ; ici, sa place sur l'accueil.
      expect(find.byType(RemindersOffCard), findsOneWidget);
      // Rendue pour de vrai : sans avis, la carte n'est qu'un `SizedBox`.
      expect(find.text('Rappels désactivés'), findsOneWidget);
    });

    testWidgets('each sign-in path opens its screen', (tester) async {
      await tester.pumpApp(auth: FakeAuthRepository());
      await tester.settleApp();

      tester.appRouter.go(AppRoutes.login);
      await tester.settleApp();
      expect(find.byType(LoginScreen), findsOneWidget);

      tester.appRouter.go(AppRoutes.signup);
      await tester.settleApp();
      expect(find.byType(SignUpScreen), findsOneWidget);
    });

    testWidgets('the sign-in pages stack above the welcome', (tester) async {
      await tester.pumpApp(auth: FakeAuthRepository());
      await tester.settleApp();
      expect(find.byType(WelcomeScreen), findsOneWidget);

      await tester.tap(find.text("J'ai déjà un compte"));
      await tester.settleApp();
      await tester.tap(find.text('Continuer avec un e-mail'));
      await tester.settleApp();
      expect(find.byType(LoginScreen), findsOneWidget);

      // L'inscription remplace la connexion par e-mail : un seul retour.
      await tester.tap(find.text("S'inscrire"));
      await tester.settleApp();
      expect(find.byType(SignUpScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Retour'));
      await tester.settleApp();
      expect(find.byType(SignUpScreen), findsNothing);
      expect(find.byType(AuthChoiceScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Retour'));
      await tester.settleApp();
      expect(find.byType(AuthChoiceScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });
}
