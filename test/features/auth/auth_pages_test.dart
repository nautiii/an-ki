import 'package:an_ki/features/auth/auth_choice_page.dart';
import 'package:an_ki/features/auth/login_page.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/auth/signup_page.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/test_harness.dart';

/// Always fails authentication and exposes an error message.
class FailingAuthNotifier extends FakeAuthNotifier {
  FailingAuthNotifier() : super(initialState: AuthState(errorMessage: 'Oops'));

  @override
  Future<bool> signInWithGoogle(AppLocalizations l10n) async => false;
  @override
  Future<bool> signInAnonymously(AppLocalizations l10n) async => false;
  @override
  Future<bool> signIn({
    required String email,
    required String password,
    required AppLocalizations l10n,
  }) async => false;
  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String surname,
    required AppLocalizations l10n,
  }) async => false;
}

/// Triggers the automatic biometric sign-in on startup.
class BiometricStartAuthNotifier extends FakeAuthNotifier {
  BiometricStartAuthNotifier(this.succeed)
    : super(
        initialState: AuthState(
          canUseBiometrics: true,
          errorMessage: succeed ? null : 'BioErr',
        ),
      );

  final bool succeed;
  bool called = false;

  @override
  Future<bool> signInWithBiometricToken(AppLocalizations l10n) async {
    called = true;
    return succeed;
  }
}

void main() {
  final signupRoute = {
    '/signup': (BuildContext _) => const Scaffold(body: Text('SignUp Route')),
  };

  group('AuthChoicePage', () {
    testWidgets('renders every option', (tester) async {
      await tester.pumpHarness(const AuthChoicePage());
      await tester.pumpAndSettle();

      expect(find.text('Connexion Google'), findsOneWidget);
      expect(find.text('Connexion Email'), findsOneWidget);
      expect(find.text('Continuer sans compte'), findsOneWidget);
    });

    testWidgets('navigates to the signup route', (tester) async {
      await tester.pumpHarness(const AuthChoicePage(), routes: signupRoute);
      await tester.pumpAndSettle();

      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();

      expect(find.text('SignUp Route'), findsOneWidget);
    });

    testWidgets('shows an error SnackBar when Google sign-in fails', (
      tester,
    ) async {
      await tester.pumpHarness(
        const AuthChoicePage(),
        overrides: [authProvider.overrideWith(FailingAuthNotifier.new)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connexion Google'));
      await tester.pumpAndSettle();

      expect(find.text('Oops'), findsOneWidget);
    });

    testWidgets('anonymous sign-in success path', (tester) async {
      final notifier = FakeAuthNotifier();
      await tester.pumpHarness(
        const AuthChoicePage(),
        overrides: [authProvider.overrideWith(() => notifier)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer sans compte'));
      await tester.pumpAndSettle();

      expect(notifier.state.user, isNotNull);
    });

    testWidgets('Google sign-in success path', (tester) async {
      final notifier = FakeAuthNotifier();
      await tester.pumpHarness(
        const AuthChoicePage(),
        overrides: [authProvider.overrideWith(() => notifier)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connexion Google'));
      await tester.pumpAndSettle();

      expect(notifier.state.user, isNotNull);
    });

    testWidgets('shows an error SnackBar when anonymous sign-in fails', (
      tester,
    ) async {
      await tester.pumpHarness(
        const AuthChoicePage(),
        overrides: [authProvider.overrideWith(FailingAuthNotifier.new)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuer sans compte'));
      await tester.pumpAndSettle();

      expect(find.text('Oops'), findsOneWidget);
    });

    testWidgets('runs biometric sign-in on startup (success)', (tester) async {
      final notifier = BiometricStartAuthNotifier(true);
      await tester.pumpHarness(
        const AuthChoicePage(),
        overrides: [authProvider.overrideWith(() => notifier)],
      );
      await tester.pumpAndSettle();

      expect(notifier.called, isTrue);
    });

    testWidgets('shows the biometric error on startup failure', (tester) async {
      await tester.pumpHarness(
        const AuthChoicePage(),
        overrides: [
          authProvider.overrideWith(() => BiometricStartAuthNotifier(false)),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('BioErr'), findsOneWidget);
    });

    testWidgets('disables the buttons while loading', (tester) async {
      await tester.pumpHarness(
        const AuthChoicePage(),
        overrides: [
          authProvider.overrideWith(
            () => FakeAuthNotifier(initialState: AuthState(isLoading: true)),
          ),
        ],
      );
      // Advance past the staggered fade-in delays to flush their timers
      // (cannot pumpAndSettle: the loading spinner animates indefinitely).
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  group('LoginPage', () {
    testWidgets('signs in successfully', (tester) async {
      final notifier = FakeAuthNotifier();
      await tester.pumpHarness(
        const LoginPage(),
        overrides: [authProvider.overrideWith(() => notifier)],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.tap(find.text('Se connecter').last);
      await tester.pumpAndSettle();

      expect(notifier.state.user, isNotNull);
    });

    testWidgets('does nothing when fields are empty', (tester) async {
      final notifier = FakeAuthNotifier();
      await tester.pumpHarness(
        const LoginPage(),
        overrides: [authProvider.overrideWith(() => notifier)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se connecter').last);
      await tester.pumpAndSettle();

      expect(notifier.state.user, isNull);
    });

    testWidgets('shows an error SnackBar on failure', (tester) async {
      await tester.pumpHarness(
        const LoginPage(),
        overrides: [authProvider.overrideWith(FailingAuthNotifier.new)],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(1), 'bad');
      await tester.tap(find.text('Se connecter').last);
      await tester.pumpAndSettle();

      expect(find.text('Oops'), findsOneWidget);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpHarness(const LoginPage());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('forgot-password button is tappable', (tester) async {
      await tester.pumpHarness(const LoginPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();
    });

    testWidgets('navigates to the signup route', (tester) async {
      await tester.pumpHarness(
        const LoginPage(),
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
        const LoginPage(),
        overrides: [
          authProvider.overrideWith(
            () => FakeAuthNotifier(initialState: AuthState(isLoading: true)),
          ),
        ],
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('back button pops the page', (tester) async {
      await tester.pumpHarness(
        const SizedBox(),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LoginPage(),
                          ),
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

  group('SignUpPage', () {
    testWidgets('shows an error when passwords do not match', (tester) async {
      await tester.pumpHarness(const SignUpPage());
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

    testWidgets('creates the account on success', (tester) async {
      final userNotifier = FakeUserNotifier(initialState: UserState());
      await tester.pumpHarness(
        const SignUpPage(),
        overrides: [
          authProvider.overrideWith(FakeAuthNotifier.new),
          userProvider.overrideWith(() => userNotifier),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'John');
      await tester.enterText(find.byType(TextField).at(1), 'Doe');
      await tester.enterText(find.byType(TextField).at(2), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(3), 'secret');
      await tester.enterText(find.byType(TextField).at(4), 'secret');

      await tester.tap(find.text("S'inscrire").last);
      await tester.pumpAndSettle();

      expect(userNotifier.state.user?.name, 'John');
    });

    testWidgets('shows an error SnackBar on failure', (tester) async {
      await tester.pumpHarness(
        const SignUpPage(),
        overrides: [authProvider.overrideWith(FailingAuthNotifier.new)],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'John');
      await tester.enterText(find.byType(TextField).at(1), 'Doe');
      await tester.enterText(find.byType(TextField).at(2), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(3), 'secret');
      await tester.enterText(find.byType(TextField).at(4), 'secret');

      await tester.tap(find.text("S'inscrire").last);
      await tester.pumpAndSettle();

      expect(find.text('Oops'), findsOneWidget);
    });

    testWidgets('toggles both password fields visibility', (tester) async {
      await tester.pumpHarness(const SignUpPage());
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
      final notifier = FakeAuthNotifier();
      await tester.pumpHarness(
        const SignUpPage(),
        overrides: [authProvider.overrideWith(() => notifier)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("S'inscrire").last);
      await tester.pumpAndSettle();

      expect(notifier.state.user, isNull);
    });

    testWidgets('navigates to the login route', (tester) async {
      await tester.pumpHarness(
        const SignUpPage(),
        routes: {'/login': (_) => const Scaffold(body: Text('Login Route'))},
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Login Route'), findsOneWidget);
    });

    testWidgets('back button pops the page', (tester) async {
      await tester.pumpHarness(
        const SignUpPage(),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SignUpPage(),
                          ),
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
        const SignUpPage(),
        overrides: [
          authProvider.overrideWith(
            () => FakeAuthNotifier(initialState: AuthState(isLoading: true)),
          ),
        ],
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
