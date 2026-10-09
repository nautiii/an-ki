import 'package:an_ki/core/common/header.dart';
import 'package:an_ki/features/auth/providers/auth_provider.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_model.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:an_ki/features/user/screens/settings_screen.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as fam;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/platform_mocks.dart';
import '../../support/test_harness.dart';

class SettingsAuthNotifier extends FakeAuthNotifier {
  SettingsAuthNotifier({super.initialState, this.throwOnDelete = false});

  final bool throwOnDelete;
  // Espion du test : champ public voulu sur ce faux notifier.
  // ignore: riverpod_lint/avoid_public_notifier_properties
  bool signedOut = false;

  @override
  Future<void> enableBiometrics() async =>
      state = state.copyWith(canUseBiometrics: true);
  @override
  Future<void> disableBiometrics() async =>
      state = state.copyWith(canUseBiometrics: false);
  @override
  Future<bool> linkWithGoogle(AppLocalizations l10n) async => true;
  @override
  Future<void> signOut(AppLocalizations l10n) async {
    signedOut = true;
    state = AuthState();
  }

  @override
  Future<void> deleteAccount(AppLocalizations l10n) async {
    if (throwOnDelete) throw Exception('delete failed');
    state = AuthState();
  }
}

User _user({bool anonymous = false}) =>
    fam.MockUser(uid: 'uid-1', isAnonymous: anonymous, displayName: 'T');

const _userModel = UserModel(
  id: 'uid-1',
  name: 'Quentin',
  surname: 'Maillard',
  pseudo: 'OldPseudo',
  isDark: false,
  locale: 'fr',
);

void main() {
  late FakeBiometricChannels channels;

  setUp(() => channels = FakeBiometricChannels()..install());
  tearDown(() => channels.uninstall());

  List<dynamic> overridesWith({
    SettingsAuthNotifier? auth,
    RecordingUserRepository? users,
  }) => [
    authProvider.overrideWith(
      () =>
          auth ?? SettingsAuthNotifier(initialState: AuthState(user: _user())),
    ),
    // Comme dans l'app : le démarrage attend le premier profil, il est donc
    // déjà là quand les réglages s'ouvrent.
    userProfileProvider.overrideWithValue(const AsyncData(_userModel)),
    userRepositoryProvider.overrideWithValue(
      users ?? RecordingUserRepository(stored: _userModel),
    ),
    birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
  ];

  testWidgets('Header opens the settings screen', (tester) async {
    await tester.pumpHarness(
      Builder(
        builder: (context) => Header(
          userName: 'Quentin',
          onOpenSettings: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
      ),
      overrides: overridesWith(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Mettre à jour le pseudo'), findsOneWidget);
  });

  testWidgets('updates the pseudo', (tester) async {
    final users = RecordingUserRepository(stored: _userModel);
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(users: users),
    );
    await tester.pumpAndSettle();

    expect(find.text('OldPseudo'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'NewPseudo');
    await tester.tap(find.text('Mettre à jour le pseudo'));
    await tester.pumpAndSettle();

    expect(users.stored?.pseudo, 'NewPseudo');
    expect(find.text('Pseudo mis à jour avec succès !'), findsOneWidget);
  });

  testWidgets('toggles the biometric switch on and off', (tester) async {
    final auth = SettingsAuthNotifier(initialState: AuthState(user: _user()));
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(auth: auth),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SwitchListTile), findsWidgets);

    await tester.tap(find.text('Connexion biométrique'));
    await tester.pumpAndSettle();
    expect(auth.state.canUseBiometrics, isTrue);

    await tester.tap(find.text('Connexion biométrique'));
    await tester.pumpAndSettle();
    expect(auth.state.canUseBiometrics, isFalse);
  });

  testWidgets('changes the language through the dropdown', (tester) async {
    final users = RecordingUserRepository(stored: _userModel);
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(users: users),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(users.stored?.locale, 'en');
  });

  testWidgets('toggles the theme', (tester) async {
    final users = RecordingUserRepository(stored: _userModel);
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(users: users),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thème'));
    await tester.pumpAndSettle();

    expect(users.stored?.isDark, isTrue);
  });

  testWidgets('shows an error when importing contacts is denied', (
    tester,
  ) async {
    // Make the contacts plugin throw so the handler hits its catch branch.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_contacts'),
          (call) async => throw PlatformException(code: 'denied'),
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_contacts'),
            null,
          ),
    );

    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importer les contacts'));
    await tester.pumpAndSettle();

    expect(find.text('Permission refusée.'), findsOneWidget);
  });

  group('sign out', () {
    testWidgets('confirms and signs out a regular account', (tester) async {
      final auth = SettingsAuthNotifier(initialState: AuthState(user: _user()));
      await tester.pumpHarness(
        const SettingsScreen(),
        overrides: overridesWith(auth: auth),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();

      expect(
        find.text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Se déconnecter').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(auth.signedOut, isTrue);
    });

    testWidgets('offers to save data for anonymous accounts', (tester) async {
      final auth = SettingsAuthNotifier(
        initialState: AuthState(user: _user(anonymous: true)),
      );
      await tester.pumpHarness(
        const SettingsScreen(),
        overrides: overridesWith(auth: auth),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();

      expect(find.text('Sauvegarder mes données'), findsOneWidget);
      await tester.tap(find.text('Sauvegarder mes données'));
      await tester.pumpAndSettle();

      expect(find.text('Compte sauvegardé avec succès !'), findsOneWidget);
    });

    testWidgets('an anonymous account can delete and leave', (tester) async {
      final auth = SettingsAuthNotifier(
        initialState: AuthState(user: _user(anonymous: true)),
      );
      await tester.pumpHarness(
        const SettingsScreen(),
        overrides: overridesWith(auth: auth),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer et quitter'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(auth.signedOut, isTrue);
    });

    testWidgets('cancelling the sign-out dialog does nothing', (tester) async {
      final auth = SettingsAuthNotifier(initialState: AuthState(user: _user()));
      await tester.pumpHarness(
        const SettingsScreen(),
        overrides: overridesWith(auth: auth),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(auth.signedOut, isFalse);
    });
  });

  testWidgets('cancelling the delete dialog does nothing', (tester) async {
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Suppression du compte'), findsNothing);
  });

  testWidgets('confirms and deletes the account', (tester) async {
    final users = RecordingUserRepository(stored: _userModel);
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(users: users),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();

    expect(find.text('Suppression du compte'), findsOneWidget);

    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    // No error SnackBar means the deletion flow completed.
    expect(find.text('Erreur lors de la suppression du compte'), findsNothing);
    expect(users.deleted, ['uid-1']);
  });

  testWidgets('shows an error when account deletion fails', (tester) async {
    final auth = SettingsAuthNotifier(
      initialState: AuthState(user: _user()),
      throwOnDelete: true,
    );
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(auth: auth),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(
      find.text('Erreur lors de la suppression du compte'),
      findsOneWidget,
    );
  });
}
