import 'package:an_ki/core/services/device_settings.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/reminders/widgets/reminders_off_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  const lea = Birthday(
    id: '1',
    name: 'Léa',
    surname: 'Martin',
    date: BirthDate(month: 3, day: 12),
  );

  late SilentNotificationService notifications;
  late FakeDeviceSettings settings;

  /// La carte en haut d'une page, comme sur l'accueil.
  Future<void> pumpCard(
    WidgetTester tester, {
    NotificationAccess access = NotificationAccess.denied,
    NotificationAccess answer = NotificationAccess.granted,
    bool dismissed = false,
    List<Birthday> birthdays = const [lea],
  }) async {
    notifications = SilentNotificationService(access: access, answer: answer);
    settings = FakeDeviceSettings(remindersOffDismissedValue: dismissed);
    await tester.pumpHarness(
      const Scaffold(
        body: Column(children: [RemindersOffCard(), Text('Héros')]),
      ),
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        birthdaysListProvider.overrideWithValue(birthdays),
        deviceSettingsProvider.overrideWithValue(settings),
      ],
    );
    await tester.pumpAndSettle();
  }

  /// Retour dans l'app, après les réglages du téléphone.
  Future<void> backToApp(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  final card = find.text('Rappels désactivés');

  testWidgets('refused: turns reminders on through the system box', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(card, findsOneWidget);

    await tester.tap(find.text('Activer'));
    await tester.pumpAndSettle();

    expect(notifications.requests, 1);
    expect(card, findsNothing);
    expect(find.text('Rappels activés'), findsOneWidget);
  });

  testWidgets('a refusal in the system box leaves the calm card', (
    tester,
  ) async {
    await pumpCard(tester, answer: NotificationAccess.denied);

    await tester.tap(find.text('Activer'));
    await tester.pumpAndSettle();

    expect(notifications.requests, 1);
    expect(card, findsOneWidget);
    expect(find.text('Rappels activés'), findsNothing);
  });

  testWidgets('blocked: leads to the settings, then goes once granted', (
    tester,
  ) async {
    await pumpCard(tester, access: NotificationAccess.blocked);
    expect(find.text('Activer'), findsNothing);

    await tester.tap(find.text('Réglages'));
    await tester.pumpAndSettle();
    expect(notifications.settingsOpened, 1);

    notifications.current = NotificationAccess.granted;
    await backToApp(tester);

    expect(card, findsNothing);
    expect(find.text('Rappels activés'), findsOneWidget);
  });

  testWidgets('the cross hides it for good, saying where reminders stay', (
    tester,
  ) async {
    await pumpCard(tester);

    await tester.tap(find.byTooltip('Masquer'));
    await tester.pumpAndSettle();

    expect(card, findsNothing);
    expect(settings.remindersOffDismissedValue, isTrue);
    expect(
      find.text('Vous pourrez toujours les activer dans les paramètres'),
      findsOneWidget,
    );
    expect(notifications.requests, 0);
  });

  testWidgets('takes no room when there is nothing to say', (tester) async {
    for (final (access, dismissed, birthdays) in [
      (NotificationAccess.granted, false, const [lea]),
      (NotificationAccess.denied, true, const [lea]),
      (NotificationAccess.denied, false, const <Birthday>[]),
    ]) {
      await pumpCard(
        tester,
        access: access,
        dismissed: dismissed,
        birthdays: birthdays,
      );

      expect(card, findsNothing, reason: '$access $dismissed $birthdays');
      expect(find.byType(Card), findsNothing);
    }
  });

  testWidgets('keeps labelled 48 dp targets', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCard(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
