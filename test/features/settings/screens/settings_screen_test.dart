import 'package:an_ki/core/common/header.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/settings/screens/settings_screen.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as fam;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

User _user({bool anonymous = false}) =>
    fam.MockUser(uid: 'uid-1', isAnonymous: anonymous, displayName: 'T');

const _profile = UserProfile(
  id: 'uid-1',
  name: 'Quentin',
  surname: 'Maillard',
  pseudo: 'OldPseudo',
  isDark: false,
  locale: 'fr',
);

/// Service de contacts dont l'utilisateur refuse la permission.
class _DeniedContactsService extends ContactsService {
  @override
  Future<bool> requestReadPermission() async => false;
}

void main() {
  /// Réglages d'une session ouverte (`uid-1`) sur un appareil à empreinte.
  List<dynamic> overridesWith({
    FakeAuthRepository? auth,
    RecordingUserRepository? users,
    FakeBiometricService? biometrics,
  }) => [
    authRepositoryProvider.overrideWithValue(
      auth ?? FakeAuthRepository(user: _user()),
    ),
    biometricServiceProvider.overrideWithValue(
      biometrics ?? FakeBiometricService(available: true),
    ),
    // Comme dans l'app : le démarrage attend le premier profil, il est donc
    // déjà là quand les réglages s'ouvrent.
    userProfileProvider.overrideWithValue(const AsyncData(_profile)),
    userRepositoryProvider.overrideWithValue(
      users ?? RecordingUserRepository(stored: _profile),
    ),
    birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
    bookRepositoryProvider.overrideWithValue(FakeBookRepository()),
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
    final users = RecordingUserRepository(stored: _profile);
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
    final biometrics = FakeBiometricService(available: true);
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(biometrics: biometrics),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SwitchListTile), findsWidgets);

    await tester.tap(find.text('Connexion biométrique'));
    await tester.pumpAndSettle();
    expect(biometrics.token, isNotNull);
    expect(find.text('Connexion biométrique activée !'), findsOneWidget);

    await tester.tap(find.text('Connexion biométrique'));
    await tester.pumpAndSettle();
    expect(biometrics.token, isNull);
  });

  testWidgets('changes the language through the dropdown', (tester) async {
    final users = RecordingUserRepository(stored: _profile);
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
    final users = RecordingUserRepository(stored: _profile);
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(users: users),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thème'));
    await tester.pumpAndSettle();

    expect(users.stored?.isDark, isTrue);
  });

  testWidgets('says so when the contacts permission is refused', (
    tester,
  ) async {
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: [
        ...overridesWith(),
        contactsServiceProvider.overrideWithValue(_DeniedContactsService()),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importer les contacts'));
    await tester.pumpAndSettle();

    expect(find.text('Permission refusée.'), findsOneWidget);
  });

  testWidgets('shows a generic error when the contacts plugin fails', (
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

    expect(find.text('Une erreur est survenue.'), findsOneWidget);
  });

  group('sign out', () {
    testWidgets('confirms and signs out a regular account', (tester) async {
      final auth = FakeAuthRepository(user: _user());
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

      expect(auth.calls, contains('signOutFirebase'));
    });

    testWidgets('offers to save data for anonymous accounts', (tester) async {
      final auth = FakeAuthRepository(user: _user(anonymous: true));
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
      final auth = FakeAuthRepository(user: _user(anonymous: true));
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

      expect(auth.calls, contains('signOutFirebase'));
    });

    testWidgets('cancelling the sign-out dialog does nothing', (tester) async {
      final auth = FakeAuthRepository(user: _user());
      await tester.pumpHarness(
        const SettingsScreen(),
        overrides: overridesWith(auth: auth),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(auth.calls, isEmpty);
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
    final users = RecordingUserRepository(stored: _profile);
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
    final auth = FakeAuthRepository(
      user: _user(),
      deleteFailure: Exception('delete failed'),
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
