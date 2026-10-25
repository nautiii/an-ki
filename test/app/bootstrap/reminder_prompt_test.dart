import 'dart:async';

import 'package:an_ki/app/bootstrap/reminder_prompt.dart';
import 'package:an_ki/core/services/contacts_service.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/auth/providers/fresh_sign_in_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthdays_added.dart';
import 'package:an_ki/features/birthday/providers/birthday_additions.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/reminders/widgets/reminder_offer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_providers.dart';
import '../../support/network_image_mock.dart';
import '../../support/test_harness.dart';

const _lea = Birthday(
  id: 'lea',
  name: 'Léa',
  surname: 'Martin',
  date: BirthDate(year: 1990, month: 3, day: 12),
);
const _hugo = Birthday(
  id: 'hugo',
  name: 'Hugo',
  surname: 'Bernard',
  date: BirthDate(month: 10, day: 21),
);

const _imported = BirthdaysAdded(count: 12, imported: true, first: false);

/// Une saisie à la main ; [first] pour la première de l'agenda.
BirthdaysAdded _byHand({bool first = false}) =>
    BirthdaysAdded(count: 1, imported: false, first: first, name: 'Léa Martin');

void main() {
  group('when to offer', () {
    late SilentNotificationService notifications;
    late StreamController<List<Birthday>> birthdays;
    late ProviderContainer container;

    /// La session `u1` sous l'invite, rappels [access] ; [freshSignIn] quand
    /// une connexion l'a ouverte pendant cette exécution.
    Future<void> pumpPrompt(
      WidgetTester tester, {
      NotificationAccess access = NotificationAccess.denied,
      bool freshSignIn = false,
    }) async {
      notifications = SilentNotificationService(access: access);
      birthdays = StreamController<List<Birthday>>();
      addTearDown(birthdays.close);
      await tester.pumpHarness(
        const ReminderPrompt(child: Text('Agenda')),
        overrides: [
          notificationServiceProvider.overrideWithValue(notifications),
          currentUidProvider.overrideWithValue('u1'),
          birthdaysProvider.overrideWith((ref) => birthdays.stream),
          if (freshSignIn)
            freshSignInProvider.overrideWithBuild((ref, notifier) => 'u1'),
        ],
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(ReminderPrompt)),
      );
      await tester.pumpAndSettle();
    }

    void add(BirthdaysAdded added) =>
        container.read(birthdayAdditionsProvider.notifier).record(added);

    /// L'écran d'ajout se ferme, l'agenda se remplit, puis la proposition.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('an import offers reminders, which say what was added', (
      tester,
    ) async {
      await pumpPrompt(tester);

      add(_imported);
      await tester.pump();
      expect(find.byType(ReminderOfferSheet), findsNothing);
      await settle(tester);

      expect(find.byType(ReminderOfferSheet), findsOneWidget);
      // La feuille le dit, une fois : pas de message en plus.
      expect(find.text('12 anniversaires ajoutés'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('with reminders on, an import is simply announced', (
      tester,
    ) async {
      await pumpPrompt(tester, access: NotificationAccess.granted);

      add(_imported);
      await settle(tester);

      expect(find.byType(ReminderOfferSheet), findsNothing);
      expect(find.text('12 anniversaires ajoutés'), findsOneWidget);
    });

    testWidgets('the first birthday by hand offers them, one more does not', (
      tester,
    ) async {
      await pumpPrompt(tester);

      add(_byHand());
      await settle(tester);
      expect(find.byType(ReminderOfferSheet), findsNothing);
      // La feuille de saisie s'est fermée : le message dit qui est arrivé.
      expect(
        find.text('Léa Martin est dans vos anniversaires'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      add(_byHand(first: true));
      await settle(tester);
      expect(find.text('1 anniversaire ajouté'), findsOneWidget);
      // La feuille l'annonce : pas de message en plus.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('with reminders on, a birthday by hand is named', (
      tester,
    ) async {
      await pumpPrompt(tester, access: NotificationAccess.granted);

      add(_byHand(first: true));
      await settle(tester);

      expect(find.byType(ReminderOfferSheet), findsNothing);
      expect(
        find.text('Léa Martin est dans vos anniversaires'),
        findsOneWidget,
      );
    });

    testWidgets('allowed meanwhile: names the first birthday by hand', (
      tester,
    ) async {
      await pumpPrompt(tester);

      add(_byHand(first: true));
      await tester.pump();
      notifications.current = NotificationAccess.granted;
      await settle(tester);

      expect(find.byType(ReminderOfferSheet), findsNothing);
      expect(
        find.text('Léa Martin est dans vos anniversaires'),
        findsOneWidget,
      );
    });

    testWidgets('offers at most once per session', (tester) async {
      await pumpPrompt(tester);
      add(_imported);
      await settle(tester);
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();

      add(const BirthdaysAdded(count: 3, imported: true, first: false));
      await settle(tester);

      expect(find.byType(ReminderOfferSheet), findsNothing);
      expect(find.text('3 anniversaires ajoutés'), findsOneWidget);
    });

    testWidgets('allowed meanwhile: announces the import instead', (
      tester,
    ) async {
      await pumpPrompt(tester);

      add(_imported);
      await tester.pump();
      notifications.current = NotificationAccess.granted;
      await settle(tester);

      expect(find.byType(ReminderOfferSheet), findsNothing);
      expect(find.text('12 anniversaires ajoutés'), findsOneWidget);
    });

    testWidgets('a sign-in that brings back an agenda offers them', (
      tester,
    ) async {
      await pumpPrompt(tester, freshSignIn: true);

      // Le cache local, vide, puis le serveur.
      birthdays.add(const []);
      await settle(tester);
      expect(find.byType(ReminderOfferSheet), findsNothing);
      birthdays.add(const [_lea, _hugo]);
      await settle(tester);

      expect(find.text('2 anniversaires retrouvés'), findsOneWidget);
      expect(notifications.requests, 0);
    });

    testWidgets('a restored session is never interrupted', (tester) async {
      await pumpPrompt(tester);

      birthdays.add(const [_lea, _hugo]);
      await settle(tester);

      expect(find.byType(ReminderOfferSheet), findsNothing);
      expect(notifications.requests, 0);
    });

    testWidgets('a sign-in with reminders already on offers nothing', (
      tester,
    ) async {
      await pumpPrompt(
        tester,
        access: NotificationAccess.granted,
        freshSignIn: true,
      );

      birthdays.add(const [_lea]);
      await settle(tester);

      expect(find.byType(ReminderOfferSheet), findsNothing);
    });
  });

  group('in the app', () {
    testWidgets('never asks for notifications at launch', (tester) async {
      await mockNetworkImages(() async {
        final notifications = SilentNotificationService(
          access: NotificationAccess.denied,
        );
        await tester.pumpApp(
          auth: FakeAuthRepository(user: MockUser()),
          birthdays: const [_lea, _hugo],
          notifications: notifications,
        );
        await tester.settleApp();

        expect(notifications.requests, 0);
        expect(find.byType(ReminderOfferSheet), findsNothing);
      });
    });

    testWidgets('importing from the empty home offers reminders', (
      tester,
    ) async {
      await mockNetworkImages(() async {
        final notifications = SilentNotificationService(
          access: NotificationAccess.denied,
        );
        await tester.pumpApp(
          auth: FakeAuthRepository(user: MockUser()),
          notifications: notifications,
          contacts: FakeContactsService(
            contacts: const [
              ImportedBirthday(
                name: 'Léa',
                surname: 'Martin',
                month: 3,
                day: 12,
              ),
              ImportedBirthday(
                name: 'Hugo',
                surname: 'Bernard',
                month: 10,
                day: 21,
              ),
            ],
          ),
        );
        await tester.settleApp();

        await tester.tap(find.text('Choisir dans mes contacts'));
        await tester.settleApp();
        await tester.tap(find.text('Ajouter 2 anniversaires'));
        await tester.settleApp();

        expect(find.byType(ReminderOfferSheet), findsOneWidget);
        expect(find.text('2 anniversaires ajoutés'), findsOneWidget);

        await tester.tap(find.text('Activer les rappels'));
        await tester.settleApp();

        expect(notifications.requests, 1);
        expect(find.byType(ReminderOfferSheet), findsNothing);
        expect(find.text('Rappels activés'), findsOneWidget);
      });
    });

    testWidgets('signing in on a new phone offers reminders for the agenda', (
      tester,
    ) async {
      await mockNetworkImages(() async {
        await tester.pumpApp(
          auth: FakeAuthRepository(),
          birthdays: const [_lea],
          notifications: SilentNotificationService(
            access: NotificationAccess.denied,
          ),
        );
        await tester.settleApp();

        await tester.tap(find.text("J'ai déjà un compte"));
        await tester.settleApp();
        await tester.tap(find.text('Continuer avec un e‑mail'));
        await tester.settleApp();
        await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
        await tester.enterText(find.byType(TextField).at(1), 'password');
        await tester.pump();
        await tester.tap(find.text('Se connecter').last);
        await tester.settleApp();

        expect(find.text('1 anniversaire retrouvé'), findsOneWidget);
      });
    });
  });
}
