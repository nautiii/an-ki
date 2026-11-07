import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/reminders/data/reminder_preferences_repository.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:an_ki/features/reminders/providers/reminder_preferences_provider.dart';
import 'package:an_ki/features/reminders/widgets/reminder_preferences_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  Future<void> pumpTiles(
    WidgetTester tester,
    AsyncValue<ReminderPreferences> preferences,
  ) async {
    await tester.pumpHarness(
      const Column(children: [ReminderLeadsTile(), ReminderTimeTile()]),
      overrides: [reminderPreferencesProvider.overrideWithValue(preferences)],
    );
    await tester.pump();
  }

  bool selected(WidgetTester tester, String label) => tester
      .widget<FilterChip>(find.widgetWithText(FilterChip, label))
      .selected;

  testWidgets('shows the leads chosen and the time', (tester) async {
    await pumpTiles(
      tester,
      const AsyncData(
        ReminderPreferences(
          leads: {ReminderLead.monthBefore, ReminderLead.sameDay},
          hour: 18,
        ),
      ),
    );

    expect(find.text('Me prévenir'), findsOneWidget);
    expect(selected(tester, '30 jours avant'), isTrue);
    expect(selected(tester, '7 jours avant'), isFalse);
    expect(selected(tester, 'La veille'), isFalse);
    // Le jour J n'a pas de puce : il est toujours prévenu.
    expect(find.widgetWithText(FilterChip, 'Le jour J'), findsNothing);
    expect(find.text('18:00'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('waits on skeletons while the setting loads', (tester) async {
    await pumpTiles(tester, const AsyncLoading());

    expect(find.byType(SkeletonBox), findsNWidgets(2));
    expect(find.byType(FilterChip), findsNothing);
  });

  testWidgets('shows the former cadence when the setting is unreadable', (
    tester,
  ) async {
    await pumpTiles(
      tester,
      AsyncError<ReminderPreferences>(Exception('denied'), StackTrace.empty),
    );

    expect(selected(tester, '7 jours avant'), isTrue);
    expect(find.text('10:00'), findsOneWidget);
  });

  group('edits the setting', () {
    late RecordingReminderPreferencesRepository preferences;

    Future<void> pumpEditable(WidgetTester tester) async {
      preferences = RecordingReminderPreferencesRepository();
      await tester.pumpHarness(
        const Column(children: [ReminderLeadsTile(), ReminderTimeTile()]),
        overrides: [
          currentUidProvider.overrideWithValue('fake-uid'),
          reminderPreferencesRepositoryProvider.overrideWithValue(preferences),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('toggles a lead before the day, the day itself staying', (
      tester,
    ) async {
      await pumpEditable(tester);

      expect(find.text('Le jour J est toujours prévenu.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'La veille'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, '7 jours avant'));
      await tester.pumpAndSettle();

      expect(preferences.saved, [
        const ReminderPreferences(
          leads: {
            ReminderLead.weekBefore,
            ReminderLead.dayBefore,
            ReminderLead.sameDay,
          },
        ),
        const ReminderPreferences(
          leads: {ReminderLead.dayBefore, ReminderLead.sameDay},
        ),
      ]);
      expect(selected(tester, 'La veille'), isTrue);
    });

    testWidgets('changes the time of the reminders', (tester) async {
      await pumpEditable(tester);

      // L'horloge fermée sans choix ne change rien.
      await tester.tap(find.text('Heure des rappels'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(preferences.saved, isEmpty);

      await tester.tap(find.text('Heure des rappels'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(preferences.saved, [const ReminderPreferences()]);
      expect(find.text('10:00'), findsOneWidget);
    });
  });
}
