import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/reminders/domain/reminder_offer.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:an_ki/features/reminders/providers/reminder_preferences_provider.dart';
import 'package:an_ki/features/reminders/widgets/reminder_offer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/test_harness.dart';

const _hugo = Birthday(
  id: 'hugo',
  name: 'Hugo',
  surname: 'Bernard',
  date: BirthDate(year: 1992, month: 10, day: 21),
);
const _louis = Birthday(
  id: 'louis',
  name: 'Louis',
  surname: 'Petit',
  date: BirthDate(month: 12, day: 2),
);

const _imported = ReminderOffer(reason: ReminderOfferReason.added, count: 12);

void main() {
  late SilentNotificationService notifications;

  /// Un écran qui ouvre la feuille, le lundi 19 octobre 2026 à 9 h, avec
  /// l'agenda [birthdays] et des rappels coupés.
  Future<void> openSheet(
    WidgetTester tester, {
    ReminderOffer offer = _imported,
    NotificationAccess answer = NotificationAccess.granted,
    List<Birthday> birthdays = const [_louis, _hugo],
    ReminderPreferences preferences = const ReminderPreferences(),
  }) async {
    notifications = SilentNotificationService(
      access: NotificationAccess.denied,
      answer: answer,
    );
    await tester.pumpHarness(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => ReminderOfferSheet.show(context, offer),
          child: const Text('Ouvrir'),
        ),
      ),
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        birthdaysProvider.overrideWithValue(AsyncData(birthdays)),
        reminderPreferencesProvider.overrideWithValue(AsyncData(preferences)),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 19, 9)),
      ],
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  /// Retour dans l'app, après la boîte système ou les réglages.
  Future<void> backToApp(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  testWidgets('says what was added, the cadence and the next real reminder', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text('12 anniversaires ajoutés'), findsOneWidget);
    expect(
      find.text('Un rappel 7 jours avant, puis le jour J'),
      findsOneWidget,
    );
    expect(find.text('À 10:00, même sans connexion.'), findsOneWidget);
    // Le prochain vrai rappel, tel que la notification l'affichera.
    expect(find.text('AnKi · mercredi 21 octobre à 10:00'), findsOneWidget);
    expect(find.text('🎂 Hugo Bernard'), findsOneWidget);
    expect(
      find.text('Hugo fête son anniversaire aujourd\'hui !'),
      findsOneWidget,
    );
    expect(find.text('Souhaiter'), findsOneWidget);
    expect(find.text('Activer les rappels'), findsOneWidget);
    expect(find.text('Plus tard'), findsOneWidget);
    expect(notifications.requests, 0);
  });

  testWidgets('follows the reminder preferences', (tester) async {
    await openSheet(
      tester,
      preferences: const ReminderPreferences(
        leads: {ReminderLead.sameDay},
        hour: 9,
      ),
    );

    expect(find.text('Un rappel le jour J'), findsOneWidget);
    expect(find.text('À 09:00, même sans connexion.'), findsOneWidget);
    expect(find.text('AnKi · mercredi 21 octobre à 09:00'), findsOneWidget);
  });

  testWidgets('says the agenda was restored after a sign-in', (tester) async {
    await openSheet(
      tester,
      offer: const ReminderOffer(
        reason: ReminderOfferReason.restored,
        count: 2,
      ),
    );

    expect(find.text('2 anniversaires retrouvés'), findsOneWidget);
  });

  testWidgets('reads the example as one block', (tester) async {
    final semantics = tester.ensureSemantics();
    await openSheet(tester);

    // « Souhaiter » n'y est pas : une image du bouton, pas une action ici.
    expect(
      tester.getSemantics(find.byType(Card)).getSemanticsData().label,
      'Exemple de rappel\n'
      'AnKi · mercredi 21 octobre à 10:00\n'
      '🎂 Hugo Bernard\n'
      'Hugo fête son anniversaire aujourd\'hui !',
    );
    semantics.dispose();
  });

  testWidgets('enabling closes the sheet and confirms', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Activer les rappels'));
    await tester.pumpAndSettle();

    expect(notifications.requests, 1);
    expect(find.byType(ReminderOfferSheet), findsNothing);
    expect(find.text('Rappels activés'), findsOneWidget);
  });

  testWidgets('a refusal closes the sheet without insisting', (tester) async {
    await openSheet(tester, answer: NotificationAccess.denied);

    await tester.tap(find.text('Activer les rappels'));
    await tester.pumpAndSettle();

    expect(find.byType(ReminderOfferSheet), findsNothing);
    expect(find.text('Rappels activés'), findsNothing);
  });

  testWidgets('blocked: leads to the settings, closes once allowed there', (
    tester,
  ) async {
    await openSheet(tester, answer: NotificationAccess.blocked);

    await tester.tap(find.text('Activer les rappels'));
    await tester.pumpAndSettle();

    expect(find.byType(ReminderOfferSheet), findsOneWidget);
    expect(
      find.text('Autorisez les notifications dans les réglages'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ouvrir les réglages'));
    await tester.pumpAndSettle();
    expect(notifications.settingsOpened, 1);

    // Revenue sans rien changer : la feuille attend.
    await backToApp(tester);
    expect(find.byType(ReminderOfferSheet), findsOneWidget);

    await tester.tap(find.text('Ouvrir les réglages'));
    await tester.pumpAndSettle();
    notifications.current = NotificationAccess.granted;
    await backToApp(tester);

    expect(find.byType(ReminderOfferSheet), findsNothing);
    expect(find.text('Rappels activés'), findsOneWidget);
  });

  testWidgets('« Plus tard » closes the sheet without asking', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();

    expect(find.byType(ReminderOfferSheet), findsNothing);
    expect(notifications.requests, 0);
  });

  testWidgets('shows no example without any birthday', (tester) async {
    await openSheet(tester, birthdays: const []);

    expect(
      find.text('Un rappel 7 jours avant, puis le jour J'),
      findsOneWidget,
    );
    expect(find.textContaining('🎂'), findsNothing);
  });

  testWidgets('meets tap target and label guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await openSheet(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('holds together on a small phone at 200 %', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await openSheet(tester);
    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // La feuille défile : son action reste atteignable.
    await tester.scrollUntilVisible(
      find.text('Activer les rappels'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Activer les rappels'), findsOneWidget);
  });
}
