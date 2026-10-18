import 'dart:async';

import 'package:an_ki/app/router/app_router.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/auth/domain/biometric_lock.dart';
import 'package:an_ki/features/auth/screens/auth_choice_screen.dart';
import 'package:an_ki/features/auth/screens/login_screen.dart';
import 'package:an_ki/features/auth/screens/signup_screen.dart';
import 'package:an_ki/features/auth/screens/welcome_screen.dart';
import 'package:an_ki/features/birthday/screens/birthday_search_screen.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/book_scanner/screens/book_scanner_screen.dart';
import 'package:an_ki/features/settings/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_mobile_scanner_platform.dart';
import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';

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

        tester.appRouter.go(AppRoutes.scanner);
        await tester.pumpAndSettle();
        expect(find.byType(BookScannerScreen), findsOneWidget);

        unawaited(tester.appRouter.push(AppRoutes.search));
        await tester.pumpAndSettle();
        expect(find.byType(BirthdaySearchScreen), findsOneWidget);
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
      });
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
      await tester.tap(find.text('Continuer avec un e‑mail'));
      await tester.settleApp();
      expect(find.byType(LoginScreen), findsOneWidget);

      // L'inscription remplace la connexion par e-mail : un seul retour.
      await tester.tap(find.text("S'inscrire"));
      await tester.settleApp();
      expect(find.byType(SignUpScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.settleApp();
      expect(find.byType(SignUpScreen), findsNothing);
      expect(find.byType(AuthChoiceScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Retour'));
      await tester.settleApp();
      expect(find.byType(AuthChoiceScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('signed out, an app path leads to the welcome', (tester) async {
      await tester.pumpApp(auth: FakeAuthRepository());
      await tester.settleApp();

      tester.appRouter.go(AppRoutes.settings);
      await tester.settleApp();

      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });
}
