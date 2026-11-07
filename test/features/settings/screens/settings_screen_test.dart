import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/book_scanner/data/book_repository.dart';
import 'package:an_ki/features/reminders/data/reminder_preferences_repository.dart';
import 'package:an_ki/features/reminders/widgets/reminder_preferences_tiles.dart';
import 'package:an_ki/features/reminders/widgets/reminders_tile.dart';
import 'package:an_ki/features/settings/screens/settings_screen.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as fam;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

User _user({bool anonymous = false}) =>
    fam.MockUser(uid: 'uid-1', isAnonymous: anonymous, displayName: 'T');

const _profile = UserProfile(
  id: 'uid-1',
  name: 'Quentin',
  surname: 'Maillard',
  pseudo: 'OldPseudo',
  locale: 'fr',
);

void main() {
  /// Réglages d'une session ouverte (`uid-1`) sur un appareil à empreinte.
  List<dynamic> overridesWith({
    FakeAuthRepository? auth,
    RecordingUserRepository? users,
    FakeBiometricService? biometrics,
    RecordingReminderPreferencesRepository? reminderPreferences,
  }) => [
    authRepositoryProvider.overrideWithValue(
      auth ?? FakeAuthRepository(user: _user()),
    ),
    biometricServiceProvider.overrideWithValue(
      biometrics ?? FakeBiometricService(available: true),
    ),
    notificationServiceProvider.overrideWithValue(SilentNotificationService()),
    // Comme dans l'app : le démarrage attend le premier profil, il est donc
    // déjà là quand les réglages s'ouvrent.
    userProfileProvider.overrideWithValue(const AsyncData(_profile)),
    userRepositoryProvider.overrideWithValue(
      users ?? RecordingUserRepository(stored: _profile),
    ),
    birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
    bookRepositoryProvider.overrideWithValue(FakeBookRepository()),
    reminderPreferencesRepositoryProvider.overrideWithValue(
      reminderPreferences ?? RecordingReminderPreferencesRepository(),
    ),
    categoryRepositoryProvider.overrideWithValue(
      RecordingCategoryRepository(const []),
    ),
  ];

  testWidgets('groups the settings in titled sections, account last', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(),
    );
    await tester.pumpAndSettle();

    const titles = [
      'Profil',
      'Préférences',
      'Anniversaires',
      'Sécurité',
      'Compte',
    ];
    for (final title in titles) {
      expect(
        tester.getSemantics(find.text(title)),
        isSemantics(label: title, isHeader: true),
      );
    }
    // Dans l'ordre de la page, la suppression du compte en dernier.
    final tops = [
      for (final text in [...titles, 'Supprimer mon compte'])
        tester.getTopLeft(find.text(text)).dy,
    ];
    expect(tops, [...tops]..sort());
    semantics.dispose();
  });

  testWidgets('hides the security section without a fingerprint', (
    tester,
  ) async {
    // Le faux service n'a pas de capteur par défaut.
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(biometrics: FakeBiometricService()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sécurité'), findsNothing);
    expect(find.text('Connexion biométrique'), findsNothing);
    expect(find.text('Compte'), findsOneWidget);
  });

  testWidgets('says when the profile could not be saved', (tester) async {
    final users = RecordingUserRepository(
      stored: _profile,
      failure: Exception('permission-denied'),
    );
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(users: users),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();

    expect(
      find.text("Quelque chose s'est mal passé. Réessayez dans un instant."),
      findsOneWidget,
    );
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
    expect(find.text('Connexion biométrique activée'), findsOneWidget);

    await tester.tap(find.text('Connexion biométrique'));
    await tester.pumpAndSettle();
    expect(biometrics.token, isNull);
  });

  testWidgets('opens the contacts import', (tester) async {
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(),
      routes: {
        AppRoutes.contactImport: (_) =>
            const Scaffold(body: Text('Import route')),
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importer les contacts'));
    await tester.pumpAndSettle();

    expect(find.text('Import route'), findsOneWidget);
  });

  testWidgets('opens the groups', (tester) async {
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(),
      routes: {
        AppRoutes.groups: (_) => const Scaffold(body: Text('Groups route')),
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Groupes'));
    await tester.pumpAndSettle();

    expect(find.text('Groups route'), findsOneWidget);
  });

  testWidgets('lists the reminder settings', (tester) async {
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(),
    );
    await tester.pumpAndSettle();

    // Leur comportement est testé avec chaque tuile ; ici, leur présence.
    expect(find.byType(RemindersTile), findsOneWidget);
    expect(find.byType(ReminderLeadsTile), findsOneWidget);
    expect(find.byType(ReminderTimeTile), findsOneWidget);
  });

  group('reminder preferences', () {
    testWidgets('says when a preference could not be saved', (tester) async {
      await tester.pumpHarness(
        const SettingsScreen(),
        overrides: overridesWith(
          reminderPreferences: RecordingReminderPreferencesRepository(
            failure: Exception('offline'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, '30 jours avant'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });
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
        find.text('Êtes-vous sûr de vouloir vous déconnecter\u00a0?'),
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

      expect(find.text('Compte sauvegardé'), findsOneWidget);
    });

    testWidgets('says why the data could not be saved', (tester) async {
      final auth = FakeAuthRepository(
        user: _user(anonymous: true),
        failure: AuthFailure.credentialAlreadyInUse,
      );
      await tester.pumpHarness(
        const SettingsScreen(),
        overrides: overridesWith(auth: auth),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sauvegarder mes données'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Ce compte Google a déjà son agenda AnKi. Choisissez-en un autre '
          'pour sauvegarder vos anniversaires.',
        ),
        findsOneWidget,
      );
      expect(find.text('Compte sauvegardé'), findsNothing);
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
}
