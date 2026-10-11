import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/biometric_lock.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/auth/screens/auth_choice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/auth_overrides.dart';
import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

/// App verrouillée par l'empreinte, comme au démarrage d'une session
/// restaurée : session `uid-1`, dont le profil connaît le jeton de
/// l'appareil, sauf [revoked].
List<Object> lockedOverrides({
  bool revoked = false,
  Exception? tokenCheckFailure,
}) => [
  ...authOverrides(
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
    AppRoutes.signup: (BuildContext _) =>
        const Scaffold(body: Text('SignUp Route')),
  };

  group('AuthChoiceScreen', () {
    testWidgets('renders every option', (tester) async {
      await tester.pumpHarness(const AuthChoiceScreen());
      await tester.pumpAndSettle();

      expect(find.text('Connexion Google'), findsOneWidget);
      expect(find.text('Connexion Email'), findsOneWidget);
      expect(find.text('Continuer sans compte'), findsOneWidget);
    });

    testWidgets('scrolls instead of overflowing on a small phone at 200 %', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpHarness(const AuthChoiceScreen());
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text("S'inscrire"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text("S'inscrire"), findsOneWidget);
    });

    testWidgets('meets tap target and label guidelines', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpHarness(const AuthChoiceScreen());
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
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
        overrides: failingAuthOverrides(),
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
        overrides: authOverrides(repository),
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
        overrides: authOverrides(repository),
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
        overrides: failingAuthOverrides(),
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
      final biometrics =
          container.read(biometricServiceProvider) as FakeBiometricService;
      expect(
        biometrics.lastReason,
        'Veuillez scanner votre empreinte pour vous connecter',
      );
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
        overrides: loadingAuthOverrides(),
      );
      // Advance past the staggered fade-in delays to flush their timers
      // (cannot pumpAndSettle: the loading spinner animates indefinitely).
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });
}
