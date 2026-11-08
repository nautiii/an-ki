import 'dart:async';

import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/birthdays_module.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/app/shell/main_shell.dart';
import 'package:an_ki/features/auth/screens/auth_choice_screen.dart';
import 'package:an_ki/features/auth/screens/login_screen.dart';
import 'package:an_ki/features/auth/screens/signup_screen.dart';
import 'package:an_ki/features/auth/screens/welcome_screen.dart';
import 'package:an_ki/features/settings/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_providers.dart';
import '../support/network_image_mock.dart';
import '../support/probe_module.dart';

/// Session qui n'arrive jamais : le démarrage reste en attente.
class _PendingAuthRepository extends FakeAuthRepository {
  @override
  Stream<User?> userChanges() => const Stream.empty();
}

/// Déconnexion Google en attente tant que [googleSignOut] n'est pas complété.
class _SlowGoogleSignOutRepository extends FakeAuthRepository {
  final googleSignOut = Completer<void>();

  @override
  Future<void> signOutGoogle() async {
    await super.signOutGoogle();
    await googleSignOut.future;
  }
}

void main() {
  testWidgets('waits for the session before choosing a screen', (tester) async {
    await tester.pumpApp(auth: _PendingAuthRepository());
    await tester.pump();

    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(MainShell), findsNothing);
  });

  testWidgets('welcomes whoever is not signed in', (tester) async {
    await tester.pumpApp(auth: FakeAuthRepository());
    await tester.settleApp();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(AuthChoiceScreen), findsNothing);
  });

  group('speaks the language of the phone', () {
    testWidgets('French on a French phone', (tester) async {
      await tester.pumpApp(auth: FakeAuthRepository());
      await tester.settleApp();

      expect(find.text('Commencer'), findsOneWidget);
    });

    testWidgets('English on an English phone', (tester) async {
      await tester.pumpApp(
        auth: FakeAuthRepository(),
        deviceLocale: const Locale('en', 'US'),
      );
      await tester.settleApp();

      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('English on a phone in an untranslated language', (
      tester,
    ) async {
      await tester.pumpApp(
        auth: FakeAuthRepository(),
        deviceLocale: const Locale('de', 'DE'),
      );
      await tester.settleApp();

      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('follows the phone when its language changes', (tester) async {
      await tester.pumpApp(auth: FakeAuthRepository());
      await tester.settleApp();
      expect(find.text('Commencer'), findsOneWidget);

      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      await tester.settleApp();

      expect(find.text('Get started'), findsOneWidget);
    });
  });

  testWidgets(
    '« Commencer » opens the app as a guest, greeted without a name',
    (tester) async {
      await mockNetworkImages(() async {
        final auth = FakeAuthRepository();
        await tester.pumpApp(auth: auth);
        await tester.settleApp();

        await tester.tap(find.text('Commencer'));
        await tester.settleApp();

        expect(auth.calls, ['signInAnonymously']);
        expect(find.byType(WelcomeScreen), findsNothing);
        expect(find.byType(MainShell), findsOneWidget);
        expect(find.textContaining('Camille'), findsNothing);
      });
    },
  );

  testWidgets('opens the app for a restored session', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpApp(auth: FakeAuthRepository(user: MockUser()));
      await tester.settleApp();

      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(AuthChoiceScreen), findsNothing);
    });
  });

  group('module effects', () {
    /// L'app connectée, la sonde au registre : renvoie combien de fois son
    /// effet a été construit. [active] : les modules actifs, sinon tous.
    Future<int> pumpWithProbe(
      WidgetTester tester, {
      List<AppModule> Function(AppModule probe)? active,
    }) async {
      var builds = 0;
      final effect = Provider<void>((ref) => builds++);
      final probe = probeModule(effects: [effect]);
      await mockNetworkImages(() async {
        await tester.pumpApp(
          auth: FakeAuthRepository(user: MockUser()),
          overrides: [
            appModulesProvider.overrideWithValue([birthdaysModule, probe]),
            if (active != null)
              activeModulesProvider.overrideWithValue(active(probe)),
          ],
        );
        await tester.settleApp();
      });
      return builds;
    }

    testWidgets('keeps the effects of the active modules alive', (
      tester,
    ) async {
      expect(await pumpWithProbe(tester), 1);
    });

    testWidgets('runs nothing for an inactive module', (tester) async {
      expect(await pumpWithProbe(tester, active: (_) => [birthdaysModule]), 0);
    });
  });

  testWidgets('keeps a restored session locked behind the fingerprint', (
    tester,
  ) async {
    await tester.pumpApp(
      auth: FakeAuthRepository(user: MockUser()),
      // Empreinte configurée, mais l'utilisateur annule l'invite.
      biometrics: FakeBiometricService(
        available: true,
        token: 'tok',
        userId: 'fake-uid',
        authenticates: false,
      ),
    );
    await tester.settleApp();

    expect(find.byType(AuthChoiceScreen), findsOneWidget);
    // L'invite fermée se relance d'un geste.
    expect(find.text('Déverrouiller'), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
  });

  testWidgets('the fingerprint opens a locked session', (tester) async {
    await mockNetworkImages(() async {
      final auth = FakeAuthRepository(user: MockUser())
        ..biometricTokens['fake-uid'] = 'tok';
      await tester.pumpApp(
        auth: auth,
        biometrics: FakeBiometricService(
          available: true,
          token: 'tok',
          userId: 'fake-uid',
        ),
      );
      await tester.settleApp();

      expect(find.byType(MainShell), findsOneWidget);
    });
  });

  testWidgets('signing in by email lands on the app', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpApp(auth: FakeAuthRepository());
      await tester.settleApp();

      await tester.tap(find.text("J'ai déjà un compte"));
      await tester.settleApp();
      await tester.tap(find.text('Continuer avec un e-mail'));
      await tester.settleApp();
      await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.pump();
      await tester.tap(find.text('Se connecter').last);
      await tester.settleApp();

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(MainShell), findsOneWidget);
    });
  });

  testWidgets('signing up lands on the app', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpApp(auth: FakeAuthRepository());
      await tester.settleApp();

      await tester.tap(find.text("J'ai déjà un compte"));
      await tester.settleApp();
      await tester.tap(find.text("S'inscrire"));
      await tester.settleApp();
      await tester.enterText(find.byType(TextField).at(0), 'John');
      await tester.enterText(find.byType(TextField).at(1), 'Doe');
      await tester.enterText(find.byType(TextField).at(2), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(3), 'secret');
      await tester.pump();
      await tester.tap(find.text("S'inscrire").last);
      await tester.settleApp();

      expect(find.byType(SignUpScreen), findsNothing);
      expect(find.byType(MainShell), findsOneWidget);
    });
  });

  testWidgets('signing out from the settings goes back to the welcome', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await tester.pumpApp(auth: FakeAuthRepository(user: MockUser()));
      await tester.settleApp();

      await tester.tap(find.byTooltip('Paramètres'));
      await tester.settleApp();
      await tester.tap(find.text('Se déconnecter'));
      await tester.settleApp();
      await tester.tap(find.text('Se déconnecter').last);
      await tester.settleApp();

      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  // Sur un téléphone, Firebase ferme la session dès la suppression, et le
  // routeur part vers la bienvenue avant que la suppression ne finisse côté
  // app (déconnexion Google lente) : rien ne doit alors dépiler la bienvenue.
  testWidgets('a guest deleting their account goes back to the welcome', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      final auth = _SlowGoogleSignOutRepository();
      await tester.pumpApp(auth: auth);
      await tester.settleApp();
      await tester.tap(find.text('Commencer'));
      await tester.settleApp();

      await tester.tap(find.byTooltip('Paramètres'));
      await tester.settleApp();
      await tester.scrollUntilVisible(
        find.text('Supprimer mon compte'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Supprimer mon compte'));
      await tester.settleApp();
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      // La session fermée, le routeur redirige pendant que la suppression
      // attend encore la déconnexion Google.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      auth.googleSignOut.complete();
      await tester.settleApp();

      expect(auth.calls, contains('deleteCurrentUser'));
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
