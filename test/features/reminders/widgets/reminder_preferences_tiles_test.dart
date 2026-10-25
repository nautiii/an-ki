import 'package:an_ki/core/common/skeleton_box.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:an_ki/features/reminders/providers/reminder_preferences_provider.dart';
import 'package:an_ki/features/reminders/widgets/reminder_preferences_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
