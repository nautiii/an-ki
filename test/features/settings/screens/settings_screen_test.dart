import 'package:an_ki/core/services/biometric_service.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/auth/domain/auth_failure.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/books/data/book_repository.dart';
import 'package:an_ki/features/settings/screens/settings_screen.dart';
import 'package:an_ki/features/settings/widgets/settings_section.dart';
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

/// Section de module qui signale son démontage.
class _DisposalProbe extends StatefulWidget {
  const _DisposalProbe({required this.onDispose});

  final VoidCallback onDispose;

  @override
  State<_DisposalProbe> createState() => _DisposalProbeState();
}

class _DisposalProbeState extends State<_DisposalProbe> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(height: 100);
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
    notificationServiceProvider.overrideWithValue(SilentNotificationService()),
    // Comme dans l'app : le démarrage attend le premier profil, il est donc
    // déjà là quand les réglages s'ouvrent.
    userProfileProvider.overrideWithValue(const AsyncData(_profile)),
    userRepositoryProvider.overrideWithValue(
      users ?? RecordingUserRepository(stored: _profile),
    ),
    birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
    bookRepositoryProvider.overrideWithValue(FakeBookRepository()),
    categoryRepositoryProvider.overrideWithValue(
      RecordingCategoryRepository(const []),
    ),
  ];

  testWidgets('groups the settings in titled sections, account last', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(
      const SettingsScreen(
        moduleSections: [
          SettingsSection(
            title: 'Module A',
            children: [ListTile(title: Text('a'))],
          ),
          SettingsSection(
            title: 'Module B',
            children: [ListTile(title: Text('b'))],
          ),
        ],
      ),
      overrides: overridesWith(),
    );
    await tester.pumpAndSettle();

    const titles = [
      'Profil',
      'Préférences',
      'Module A',
      'Module B',
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

  testWidgets('puts the modules row last of the preferences', (tester) async {
    await tester.pumpHarness(
      const SettingsScreen(
        modulesTile: ListTile(title: Text('Ligne modules')),
        moduleSections: [
          SettingsSection(
            title: 'Module A',
            children: [ListTile(title: Text('a'))],
          ),
        ],
      ),
      overrides: overridesWith(),
    );
    await tester.pumpAndSettle();

    final tops = [
      for (final text in ['Préférences', 'Langue', 'Ligne modules', 'Module A'])
        tester.getTopLeft(find.text(text)).dy,
    ];
    expect(tops, [...tops]..sort());
  });

  testWidgets('shows no module section when given none', (tester) async {
    await tester.pumpHarness(
      const SettingsScreen(),
      overrides: overridesWith(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Préférences'), findsOneWidget);
    expect(find.text('Sécurité'), findsOneWidget);
    expect(find.text('Anniversaires'), findsNothing);
  });

  testWidgets('keeps a module section mounted once scrolled away', (
    tester,
  ) async {
    var disposals = 0;
    await tester.pumpHarness(
      SettingsScreen(
        moduleSections: [
          _DisposalProbe(onDispose: () => disposals++),
          // Une section haute : la sonde sort loin de l'écran.
          const SizedBox(height: 3000),
        ],
      ),
      overrides: overridesWith(),
    );
    await tester.pumpAndSettle();

    // Bien au-delà de la zone qu'une liste paresseuse garde construite.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -5000));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer mon compte'), findsOneWidget);
    expect(disposals, 0);
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
