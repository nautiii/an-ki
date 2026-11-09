import 'dart:async' hide AsyncError;

import 'package:an_ki/app/modules/module_data_hooks.dart';
import 'package:an_ki/app/modules/modules_screen.dart';
import 'package:an_ki/core/providers/user_data_hooks.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_providers.dart';
import '../../support/test_harness.dart';

const _profile = UserProfile(id: 'u1', name: 'Camille', surname: 'Durand');

void main() {
  late RecordingUserRepository users;
  late List<String> erased;

  setUp(() {
    users = RecordingUserRepository(stored: _profile);
    erased = [];
  });

  /// L'écran, connecté comme `u1` au profil de [users] ; [eraseBooks] efface
  /// les livres (par défaut : il note l'effacement).
  Future<void> pumpScreen(
    WidgetTester tester, {
    UserDataEraser? eraseBooks,
    List<Override> overrides = const [],
  }) => tester.pumpHarness(
    const ModulesScreen(),
    overrides: [
      currentUidProvider.overrideWithValue('u1'),
      userRepositoryProvider.overrideWithValue(users),
      moduleErasersProvider.overrideWithValue({
        'books': eraseBooks ?? (uid) async => erased.add(uid),
      }),
      ...overrides,
    ],
  );

  Finder booksSwitch() => find.widgetWithText(SwitchListTile, 'Livres');

  testWidgets('says what a module does, and that Birthdays is always on', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('Modules'), findsOneWidget);
    expect(
      find.text(
        "Choisissez ce qu'AnKi fait pour vous. "
        'Un module désactivé garde vos données.',
      ),
      findsOneWidget,
    );
    expect(find.text('Anniversaires'), findsOneWidget);
    expect(find.text('Qui fête quoi, et quand le souhaiter'), findsOneWidget);
    expect(find.text('Toujours actif'), findsOneWidget);
    // Un seul interrupteur : Anniversaires n'en a pas.
    expect(find.byType(Switch), findsOneWidget);
    expect(tester.widget<SwitchListTile>(booksSwitch()).value, isFalse);
    // Les données d'Anniversaires partent avec le compte, pas d'ici.
    expect(find.text('Effacer les données Livres…'), findsOneWidget);
    expect(find.textContaining('Effacer les données Anniv'), findsNothing);
  });

  testWidgets('a tap on the row turns Books on, then off, without a dialog', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Livres'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(users.stored?.moduleChoices, {'books': true});
    expect(tester.widget<SwitchListTile>(booksSwitch()).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(users.stored?.moduleChoices, {'books': false});
    expect(tester.widget<SwitchListTile>(booksSwitch()).value, isFalse);
  });

  testWidgets('waits for the profile with the shape of each switch', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      overrides: [userProfileProvider.overrideWithValue(const AsyncLoading())],
    );
    await tester.pump();

    expect(find.text('Livres'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Chargement des modules')), findsOne);
  });

  testWidgets('without a profile document yet, the switch waits', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      overrides: [userProfileProvider.overrideWithValue(const AsyncData(null))],
    );
    await tester.pumpAndSettle();

    final books = tester.widget<SwitchListTile>(booksSwitch());
    expect(books.value, isFalse);
    expect(books.onChanged, isNull);
  });

  testWidgets('an unreadable profile says so and retries', (tester) async {
    await pumpScreen(
      tester,
      overrides: [
        userProfileProvider.overrideWithValue(
          AsyncError(Exception('unavailable'), StackTrace.empty),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Modules indisponibles'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  group('erasing the Books data', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.text('Effacer les données Livres…'));
      await tester.pumpAndSettle();
    }

    testWidgets('names the data and says it is final', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();
      await openDialog(tester);

      expect(find.text('Effacer les données Livres ?'), findsOneWidget);
      expect(find.textContaining("C'est définitif."), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(erased, isEmpty);
    });

    testWidgets('erases them, keeps the module as it was, and says so', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();
      await openDialog(tester);

      await tester.tap(find.text('Effacer'));
      await tester.pumpAndSettle();

      expect(erased, ['u1']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Données Livres effacées'), findsOneWidget);
      expect(users.stored?.moduleChoices, isEmpty);
    });

    testWidgets('shows its progress, and erases once only', (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await pumpScreen(
        tester,
        eraseBooks: (_) {
          calls++;
          return pending.future;
        },
      );
      await tester.pumpAndSettle();
      await openDialog(tester);

      await tester.tap(find.text('Effacer'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.bySemanticsLabel('Effacement en cours…'), findsOneWidget);
      await tester.tap(find.text('Effacer'));
      await tester.pump();
      expect(calls, 1);

      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Données Livres effacées'), findsOneWidget);
    });

    testWidgets('closes while it erases, and still says how it ended', (
      tester,
    ) async {
      // Hors ligne après la lecture : l'écriture attend le réseau.
      final pending = Completer<void>();
      await pumpScreen(tester, eraseBooks: (_) => pending.future);
      await tester.pumpAndSettle();
      await openDialog(tester);
      await tester.tap(find.text('Effacer'));
      await tester.pump();

      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ModulesScreen), findsOneWidget);

      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ModulesScreen), findsOneWidget);
      expect(find.text('Données Livres effacées'), findsOneWidget);
    });

    testWidgets('offline, erases nothing and says why', (tester) async {
      await pumpScreen(
        tester,
        eraseBooks: (_) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );
      await tester.pumpAndSettle();
      await openDialog(tester);

      await tester.tap(find.text('Effacer'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text(
          "Les données Livres n'ont pas pu être effacées. "
          'Vérifiez votre connexion et réessayez.',
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('meets tap target and label guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('holds at 200 % text on a small phone', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpScreen(tester);
    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Effacer les données Livres…'),
      200,
    );
    expect(find.text('Effacer les données Livres…'), findsOneWidget);
  });
}
