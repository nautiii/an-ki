import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/person_reminders_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  Birthday lea({Set<ReminderLead>? reminders}) => Birthday(
    id: 'lea',
    name: 'Léa',
    surname: 'Martin',
    date: const BirthDate(year: 1990, month: 10, day: 24),
    reminders: reminders,
  );

  late RecordingBirthdayRepository repository;
  late StreamController<List<Birthday>> birthdays;

  /// La ligne de [person], la liste servie par [birthdays], que le test
  /// fait évoluer comme Firestore.
  Future<void> pump(WidgetTester tester, Birthday person) async {
    repository = RecordingBirthdayRepository();
    birthdays = StreamController<List<Birthday>>();
    // Sans écouteur (feuille jamais ouverte), close() ne se termine pas :
    // on ne l'attend pas.
    addTearDown(() => unawaited(birthdays.close()));
    await tester.pumpHarness(
      Center(child: PersonRemindersTile(birthday: person)),
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 12)),
        currentUidProvider.overrideWithValue('fake-uid'),
        birthdaysProvider.overrideWith((ref) => birthdays.stream),
        birthdayRepositoryProvider.overrideWithValue(repository),
      ],
    );
    birthdays.add([person]);
    await tester.pump();
  }

  ChoiceChip choice(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byType(PersonRemindersTile));
    await tester.pumpAndSettle();
  }

  group('sums up', () {
    testWidgets('the usual cadence', (tester) async {
      await pump(tester, lea());

      expect(find.text('Rappels'), findsOneWidget);
      expect(find.text("Comme d'habitude"), findsOneWidget);
      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
    });

    testWidgets('a muted person', (tester) async {
      await pump(tester, lea(reminders: const {}));

      expect(find.text('Aucun rappel'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_off_rounded), findsOneWidget);
    });

    testWidgets('their own moments, in time order', (tester) async {
      await pump(
        tester,
        lea(reminders: {ReminderLead.sameDay, ReminderLead.monthBefore}),
      );

      expect(find.text('30 jours avant · Le jour J'), findsOneWidget);
    });
  });

  group('sheet', () {
    testWidgets('writes a choice at once, then shows it once saved', (
      tester,
    ) async {
      await pump(tester, lea());
      await openSheet(tester);
      expect(choice(tester, "Comme d'habitude").selected, isTrue);

      await tester.tap(find.text('Aucun'));
      await tester.pump();
      expect(repository.reminderUpdates.single.$1, 'lea');
      expect(repository.reminderUpdates.single.$2, isEmpty);

      // Firestore renvoie la personne à jour : la feuille la suit.
      birthdays.add([lea(reminders: const {})]);
      await tester.pump();
      expect(choice(tester, 'Aucun').selected, isTrue);
      expect(choice(tester, "Comme d'habitude").selected, isFalse);
    });

    testWidgets('closes when the person is deleted meanwhile', (tester) async {
      await pump(tester, lea());
      await openSheet(tester);
      expect(find.byType(PersonRemindersSheet), findsOneWidget);

      birthdays.add(const []);
      await tester.pumpAndSettle();

      expect(find.byType(PersonRemindersSheet), findsNothing);
      expect(repository.reminderUpdates, isEmpty);
    });
  });

  testWidgets('a 48 dp button, read with its summary', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, lea());

    expect(
      tester.getSemantics(find.byType(ListTile)),
      isSemantics(
        label: "Rappels\nComme d'habitude",
        isButton: true,
        hasTapAction: true,
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
