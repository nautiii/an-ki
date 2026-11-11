import 'dart:async';

import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/screens/home_screen.dart';
import 'package:an_ki/features/books/screens/shelf_screen.dart';
import 'package:an_ki/core/routing/app_routes.dart';
import 'package:an_ki/features/settings/screens/settings_screen.dart';
import 'package:an_ki/features/settings/widgets/guest_backup_card.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_mobile_scanner_platform.dart';
import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';

void main() {
  setUp(FakeMobileScannerPlatform.install);

  final title = find.text('Nouveau · Livres');
  final later = find.widgetWithText(TextButton, 'Plus tard');
  final tryIt = find.widgetWithText(FilledButton, 'Essayer');

  List<Birthday> agenda(int count) => [
    for (var i = 0; i < count; i++)
      Birthday(
        id: 'b$i',
        name: 'Personne$i',
        surname: 'X',
        date: BirthDate.fromDate(DateTime(1990, 1 + i, 10)),
      ),
  ];

  UserProfile profile([Map<String, bool> modules = const {}]) => UserProfile(
    id: 'fake-uid',
    name: 'Camille',
    surname: 'Durand',
    locale: 'fr',
    moduleChoices: modules,
  );

  Future<void> pump(
    WidgetTester tester, {
    int birthdays = 1,
    Map<String, bool> modules = const {},
    RecordingUserRepository? users,
    bool guest = false,
  }) async {
    await tester.pumpApp(
      auth: FakeAuthRepository(user: MockUser(isAnonymous: guest)),
      birthdays: agenda(birthdays),
      users: users ?? RecordingUserRepository(stored: profile(modules)),
    );
    await tester.settleApp();
  }

  testWidgets('shows after the agenda while Books has no explicit choice', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pump(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(title, findsOneWidget);
      expect(
        find.text(
          'Suivez vos séries : le dernier tome acheté, le prochain et '
          'sa date de sortie.',
        ),
        findsOneWidget,
      );
      expect(later, findsOneWidget);
      expect(tryIt, findsOneWidget);
      // Après l'agenda, jamais au-dessus du héros.
      final agendaTile = find.textContaining('Personne0').last;
      expect(
        tester.getTopLeft(title).dy,
        greaterThan(tester.getTopLeft(agendaTile).dy),
      );
    });
  });

  testWidgets('never shows on the first run, with an empty agenda', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pump(tester, birthdays: 0);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(title, findsNothing);
    });
  });

  testWidgets('hides once Books has a choice, either way', (tester) async {
    await mockNetworkImages(() async {
      await pump(tester, modules: const {'books': false});
      expect(title, findsNothing);
    });
    await mockNetworkImages(() async {
      await pump(tester, modules: const {'books': true});
      expect(title, findsNothing);
    });
  });

  testWidgets('the buttons are labelled and 48 dp wide enough to tap', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      expect(find.bySemanticsLabel('Plus tard'), findsOneWidget);
      expect(find.bySemanticsLabel('Essayer'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  testWidgets('« Plus tard » writes books: false and hides the card', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      final users = RecordingUserRepository(stored: profile());
      await pump(tester, users: users);

      await tester.tap(later);
      await tester.pumpAndSettle();

      expect(users.stored?.moduleChoices, {'books': false});
      expect(title, findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ShelfScreen), findsNothing);
    });
  });

  testWidgets('« Essayer » enables Books and opens the shelf', (tester) async {
    await mockNetworkImages(() async {
      final users = RecordingUserRepository(stored: profile());
      await pump(tester, users: users);

      await tester.tap(tryIt);
      await tester.pumpAndSettle();

      expect(users.stored?.moduleChoices, {'books': true});
      expect(find.byType(ShelfScreen), findsOneWidget);
      expect(tester.appRouter.state.uri.path, '/books');
    });
  });

  testWidgets('the card stays usable when the write fails', (tester) async {
    await mockNetworkImages(() async {
      final users = RecordingUserRepository(
        stored: profile(),
        failure: Exception('offline'),
      );
      await pump(tester, users: users);

      await tester.tap(tryIt);
      await tester.pumpAndSettle();

      expect(find.byType(ShelfScreen), findsNothing);
      expect(title, findsOneWidget);
      expect(tester.widget<FilledButton>(tryIt).onPressed, isNotNull);
      expect(find.textContaining('Quelque chose s'), findsOneWidget);
    });
  });

  testWidgets('a failed « Plus tard » keeps the card and says so', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      final users = RecordingUserRepository(
        stored: profile(),
        failure: Exception('offline'),
      );
      await pump(tester, users: users);

      await tester.tap(later);
      await tester.pumpAndSettle();

      expect(title, findsOneWidget);
      expect(find.textContaining('Quelque chose s'), findsOneWidget);
    });
  });

  testWidgets('does not pull the user off the page they moved to', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      final gate = Completer<void>();
      final users = _GatedUserRepository(profile(), gate.future);
      await pump(tester, users: users);

      await tester.tap(tryIt);
      await tester.pump();
      // Avant que l'activation arrive, l'utilisateur ouvre les Réglages.
      unawaited(tester.appRouter.push(AppRoutes.settings));
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(ShelfScreen), findsNothing);
    });
  });

  testWidgets('both buttons wait while « Essayer » activates the module', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      final gate = Completer<void>();
      final users = _GatedUserRepository(profile(), gate.future);
      await pump(tester, users: users);

      await tester.tap(tryIt);
      await tester.pump();

      expect(title, findsOneWidget);
      expect(tester.widget<FilledButton>(tryIt).onPressed, isNull);
      expect(tester.widget<TextButton>(later).onPressed, isNull);
      expect(find.byType(ShelfScreen), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(ShelfScreen), findsOneWidget);
    });
  });

  testWidgets('sits below the guest backup card when both show', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pump(tester, birthdays: 3, guest: true);

      expect(find.byType(GuestBackupCard), findsOneWidget);
      expect(title, findsOneWidget);
      expect(
        tester.getTopLeft(title).dy,
        greaterThan(tester.getBottomLeft(find.byType(GuestBackupCard)).dy),
      );
    });
  });
}

/// Dépôt dont l'écriture d'un module n'aboutit qu'une fois [gate] terminé.
class _GatedUserRepository extends RecordingUserRepository {
  _GatedUserRepository(UserProfile stored, this.gate) : super(stored: stored);

  final Future<void> gate;

  @override
  Future<void> setModuleEnabled(
    String uid,
    String moduleId, {
    required bool enabled,
  }) async {
    await gate;
    return super.setModuleEnabled(uid, moduleId, enabled: enabled);
  }
}
