import 'dart:async';

import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/auth/domain/biometric_lock.dart';
import 'package:an_ki/features/auth/providers/auth_controller.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/auth/providers/sign_up_names_provider.dart';
import 'package:an_ki/features/auth/screens/auth_choice_screen.dart';
import 'package:an_ki/features/auth/screens/login_screen.dart';
import 'package:an_ki/features/auth/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/test_harness.dart';

/// Overrides autour d'un faux dépôt d'authentification (qui enregistre les
/// appels) et d'un faux service biométrique.
List<Object> withRepository(
  FakeAuthRepository repository, {
  FakeBiometricService? biometrics,
}) => [
  authRepositoryProvider.overrideWithValue(repository),
  biometricServiceProvider.overrideWithValue(
    biometrics ?? FakeBiometricService(),
  ),
];

/// Toutes les connexions échouent.
List<Object> failingOverrides() =>
    withRepository(FakeAuthRepository(failure: AuthFailure.unknown));

/// Une opération est en cours.
List<Object> loadingOverrides() => [
  ...withRepository(FakeAuthRepository()),
  authControllerProvider.overrideWithBuild(
    (ref, notifier) => Completer<void>().future,
  ),
];

/// App verrouillée par l'empreinte, comme au démarrage d'une session
/// restaurée : session `uid-1`, dont le profil connaît le jeton de
/// l'appareil, sauf [revoked].
List<Object> lockedOverrides({
  bool revoked = false,
  Exception? tokenCheckFailure,
}) => [
  ...withRepository(
    FakeAuthRepository(
      user: MockUser(uid: 'uid-1'),
      tokenCheckFailure: tokenCheckFailure,
    )..biometricTokens['uid-1'] = revoked ? 'other-device' : 'tok',
    biometrics: FakeBiometricService(
      available: true,
      token: 'tok',
      userId: 'uid-1',
    ),
  ),
  // `App` attend la session et le verrou avant de monter cet écran.
  authUserProvider.overrideWithValue(AsyncData(MockUser(uid: 'uid-1'))),
  biometricLockProvider.overrideWithBuild(
    (ref, notifier) => const BiometricLock(enabled: true),
  ),
];

void main() {
  final signupRoute = {
    '/signup': (BuildContext _) => const Scaffold(body: Text('SignUp Route')),
  };

  group('AuthChoiceScreen', () {
    testWidgets('renders every option', (tester) async {
      await tester.pumpHarness(const AuthChoiceScreen());
      await tester.pumpAndSettle();

      expect(find.text('Connexion Google'), findsOneWidget);
      expect(find.text('Connexion Email'), findsOneWidget);
      expect(find.text('Continuer sans compte'), findsOneWidget);
    });

    testWidgets('navigates to the signup route', (tester) async {
      await tester.pumpHarness(const AuthChoiceScreen(), routes: signupRoute);
      await tester.pumpAndSettle();

      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();

      expect(find.text('SignUp Route'), findsOneWidget);
    });

    testWidgets('shows an error SnackBar when Google sign-in fails', (
      tester,
    ) async {
      await tester.pumpHarness(
        const AuthChoiceScreen(),
        overrides: failingOverrides(),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connexion Google'));
      await tester.pumpAndSettle();

      expect(find.text('Une erreur est survenue.'), findsOneWidget);
    });

    testWidgets('anonymous sign-in success path', (tester) async {
      final repository = FakeAuthRepository();
      await tester.pumpHarness(
        const AuthChoiceScreen(),
        overrides: withRepository(repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer sans compte'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['signInAnonymously']);
      expect(repository.currentUser?.isAnonymous, isTrue);
    });

    testWidgets('Google sign-in success path', (tester) async {
      final repository = FakeAuthRepository();
      await tester.pumpHarness(
        const AuthChoiceScreen(),
        overrides: withRepository(repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connexion Google'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['signInWithGoogle']);
      expect(repository.currentUser, isNotNull);
    });

    testWidgets('shows an error SnackBar when anonymous sign-in fails', (
      tester,
    ) async {
      await tester.pumpHarness(
        const AuthChoiceScreen(),
        overrides: failingOverrides(),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer sans compte'));
      await tester.pumpAndSettle();

      expect(find.text('Une erreur est survenue.'), findsOneWidget);
    });

    testWidgets('unlocks with the fingerprint on startup', (tester) async {
      await tester.pumpHarness(
        const AuthChoiceScreen(),
        overrides: lockedOverrides(),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AuthChoiceScreen)),
      );

      expect(container.read(authAccessProvider), AuthAccess.granted);
    });

    testWidgets('shows the biometric error on startup failure', (tester) async {
      await tester.pumpHarness(
        const AuthChoiceScreen(),
        overrides: lockedOverrides(
          tokenCheckFailure: Exception('lookup failed'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Erreur lors de l'authentification biométrique"),
        findsOneWidget,
      );
    });

    testWidgets('signs out and says why when the fingerprint is revoked', (
      tester,
    ) async {
      await tester.pumpHarness(
        const AuthChoiceScreen(),
        overrides: lockedOverrides(revoked: true),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AuthChoiceScreen)),
      );

      expect(
        find.text(
          "La connexion biométrique n'est plus valide. "
          'Reconnectez-vous pour continuer.',
        ),
        findsOneWidget,
      );
      final repository =
          container.read(authRepositoryProvider) as FakeAuthRepository;
      expect(repository.calls, contains('signOutFirebase'));
    });

    testWidgets('disables the buttons while loading', (tester) async {
      await tester.pumpHarness(
        const AuthChoiceScreen(),
        overrides: loadingOverrides(),
      );
      // Advance past the staggered fade-in delays to flush their timers
      // (cannot pumpAndSettle: the loading spinner animates indefinitely).
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  group('LoginScreen', () {
    testWidgets('signs in successfully', (tester) async {
      final repository = FakeAuthRepository();
      await tester.pumpHarness(
        const LoginScreen(),
        overrides: withRepository(repository),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.tap(find.text('Se connecter').last);
      await tester.pumpAndSettle();

      expect(repository.calls, ['signInWithEmail']);
      expect(repository.currentUser, isNotNull);
    });

    testWidgets('does nothing when fields are empty', (tester) async {
      final repository = FakeAuthRepository();
      await tester.pumpHarness(
        const LoginScreen(),
        overrides: withRepository(repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se connecter').last);
      await tester.pumpAndSettle();

      expect(repository.calls, isEmpty);
    });

    testWidgets('shows an error SnackBar on failure', (tester) async {
      await tester.pumpHarness(
        const LoginScreen(),
        overrides: failingOverrides(),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(1), 'bad');
      await tester.tap(find.text('Se connecter').last);
      await tester.pumpAndSettle();

      expect(find.text('Une erreur est survenue.'), findsOneWidget);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpHarness(const LoginScreen());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('forgot-password button is tappable', (tester) async {
      await tester.pumpHarness(const LoginScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();
    });

    testWidgets('navigates to the signup route', (tester) async {
      await tester.pumpHarness(
        const LoginScreen(),
        routes: {'/signup': (_) => const Scaffold(body: Text('SignUp Route'))},
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();

      expect(find.text('SignUp Route'), findsOneWidget);
    });

    testWidgets('disables inputs and shows a spinner while loading', (
      tester,
    ) async {
      await tester.pumpHarness(
        const LoginScreen(),
        overrides: loadingOverrides(),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('back button pops the page', (tester) async {
      await tester.pumpHarness(
        const SizedBox(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
    });
  });

  group('SignUpScreen', () {
    testWidgets('shows an error when passwords do not match', (tester) async {
      await tester.pumpHarness(const SignUpScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'John');
      await tester.enterText(find.byType(TextField).at(1), 'Doe');
      await tester.enterText(find.byType(TextField).at(2), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(3), 'secret1');
      await tester.enterText(find.byType(TextField).at(4), 'secret2');

      await tester.tap(find.text("S'inscrire").last);
      await tester.pumpAndSettle();

      expect(
        find.text('Les mots de passe ne correspondent pas'),
        findsOneWidget,
      );
    });

    testWidgets('keeps the typed names for the profile on success', (
      tester,
    ) async {
      await tester.pumpHarness(
        const SignUpScreen(),
        overrides: withRepository(FakeAuthRepository()),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SignUpScreen)),
      );

      await tester.enterText(find.byType(TextField).at(0), 'John');
      await tester.enterText(find.byType(TextField).at(1), 'Doe');
      await tester.enterText(find.byType(TextField).at(2), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(3), 'secret');
      await tester.enterText(find.byType(TextField).at(4), 'secret');

      await tester.tap(find.text("S'inscrire").last);
      await tester.pumpAndSettle();

      // app/bootstrap créera le profil avec ces noms tels que saisis.
      expect(container.read(signUpNamesProvider), (
        name: 'John',
        surname: 'Doe',
      ));
    });

    testWidgets('shows an error SnackBar on failure', (tester) async {
      await tester.pumpHarness(
        const SignUpScreen(),
        overrides: failingOverrides(),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SignUpScreen)),
      );

      await tester.enterText(find.byType(TextField).at(0), 'John');
      await tester.enterText(find.byType(TextField).at(1), 'Doe');
      await tester.enterText(find.byType(TextField).at(2), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(3), 'secret');
      await tester.enterText(find.byType(TextField).at(4), 'secret');

      await tester.tap(find.text("S'inscrire").last);
      await tester.pumpAndSettle();

      expect(find.text('Une erreur est survenue.'), findsOneWidget);
      // Inscription ratée : rien ne doit rester pour une connexion suivante.
      expect(container.read(signUpNamesProvider), isNull);
    });

    testWidgets('toggles both password fields visibility', (tester) async {
      await tester.pumpHarness(const SignUpScreen());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.visibility_off_outlined).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Toggle the confirm-password field too.
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
    });

    testWidgets('does nothing when mandatory fields are empty', (tester) async {
      final repository = FakeAuthRepository();
      await tester.pumpHarness(
        const SignUpScreen(),
        overrides: withRepository(repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("S'inscrire").last);
      await tester.pumpAndSettle();

      expect(repository.calls, isEmpty);
    });

    testWidgets('navigates to the login route', (tester) async {
      await tester.pumpHarness(
        const SignUpScreen(),
        routes: {'/login': (_) => const Scaffold(body: Text('Login Route'))},
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Login Route'), findsOneWidget);
    });

    testWidgets('back button pops the page', (tester) async {
      await tester.pumpHarness(
        const SignUpScreen(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('disables inputs while loading', (tester) async {
      await tester.pumpHarness(
        const SignUpScreen(),
        overrides: loadingOverrides(),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
