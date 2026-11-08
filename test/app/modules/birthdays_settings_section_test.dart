import 'package:an_ki/app/modules/birthdays_settings_section.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/data/auth_repository.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/reminders/data/reminder_preferences_repository.dart';
import 'package:an_ki/features/reminders/widgets/reminder_preferences_tiles.dart';
import 'package:an_ki/features/reminders/widgets/reminders_tile.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as fam;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_providers.dart';
import '../../support/test_harness.dart';

const _profile = UserProfile(
  id: 'uid-1',
  name: 'Quentin',
  surname: 'Maillard',
  pseudo: 'OldPseudo',
  locale: 'fr',
);

/// La section, dans une page qui défile comme les Réglages.
const _page = Scaffold(
  body: SingleChildScrollView(child: BirthdaysSettingsSection()),
);

void main() {
  /// Réglages d'une session ouverte (`uid-1`).
  List<dynamic> overridesWith({
    RecordingReminderPreferencesRepository? reminderPreferences,
  }) => [
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository(
        user: fam.MockUser(uid: 'uid-1', displayName: 'T'),
      ),
    ),
    notificationServiceProvider.overrideWithValue(SilentNotificationService()),
    userProfileProvider.overrideWithValue(const AsyncData(_profile)),
    userRepositoryProvider.overrideWithValue(
      RecordingUserRepository(stored: _profile),
    ),
    birthdayRepositoryProvider.overrideWithValue(FakeBirthdayRepository()),
    reminderPreferencesRepositoryProvider.overrideWithValue(
      reminderPreferences ?? RecordingReminderPreferencesRepository(),
    ),
    categoryRepositoryProvider.overrideWithValue(
      RecordingCategoryRepository(const []),
    ),
  ];

  testWidgets('is titled Anniversaires', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(_page, overrides: overridesWith());
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('Anniversaires')),
      isSemantics(label: 'Anniversaires', isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('opens the contacts import', (tester) async {
    await tester.pumpHarness(
      _page,
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
      _page,
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
    await tester.pumpHarness(_page, overrides: overridesWith());
    await tester.pumpAndSettle();

    // Leur comportement est testé avec chaque tuile ; ici, leur présence.
    expect(find.byType(RemindersTile), findsOneWidget);
    expect(find.byType(ReminderLeadsTile), findsOneWidget);
    expect(find.byType(ReminderTimeTile), findsOneWidget);
  });

  group('reminder preferences', () {
    testWidgets('says when a preference could not be saved', (tester) async {
      await tester.pumpHarness(
        _page,
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
      expect(
        find.text("Quelque chose s'est mal passé. Réessayez dans un instant."),
        findsOneWidget,
      );
    });
  });
}
