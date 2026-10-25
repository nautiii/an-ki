import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/domain/birthday_groups.dart';
import 'package:an_ki/features/birthday/providers/group_entries.dart';
import 'package:an_ki/features/birthday/screens/groups_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

const _family = BirthdayCategory(id: 'fam', name: 'family', icon: 0xe148);
const _book = BirthdayCategory(
  id: 'book',
  name: 'Club de lecture',
  icon: 0xe148,
  tone: 4,
);
const _goat = BirthdayCategory(id: 'goat', name: 'goat', icon: 0xe148);

const _entries = [
  GroupEntry(category: _family, kind: GroupKind.preset, count: 3),
  GroupEntry(category: _book, kind: GroupKind.own, count: 1),
  GroupEntry(category: _goat, kind: GroupKind.shared, count: 0),
];

void main() {
  Future<void> pumpGroups(
    WidgetTester tester,
    AsyncValue<List<GroupEntry>> entries,
  ) => tester.pumpHarness(
    const GroupsScreen(),
    overrides: [groupEntriesProvider.overrideWithValue(entries)],
  );

  testWidgets('lists the groups with their people, presets locked', (
    tester,
  ) async {
    await pumpGroups(tester, const AsyncData(_entries));

    expect(find.text('Famille'), findsOneWidget);
    expect(find.text('3 personnes · Proposé à tous'), findsOneWidget);
    expect(find.text('Club de lecture'), findsOneWidget);
    expect(find.text('1 personne'), findsOneWidget);
    expect(find.text('GOAT'), findsOneWidget);
    expect(find.text('Aucune personne'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
  });

  testWidgets('shows a skeleton while the groups load', (tester) async {
    await pumpGroups(tester, const AsyncLoading());

    expect(find.text('Famille'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('says the groups are unavailable, with a retry', (tester) async {
    await pumpGroups(tester, AsyncError(Exception('down'), StackTrace.empty));

    expect(find.text('Groupes indisponibles'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('opens the edit sheet of an own group only', (tester) async {
    await pumpGroups(tester, const AsyncData(_entries));

    await tester.tap(find.text('Famille'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le groupe'), findsNothing);

    await tester.tap(find.text('Club de lecture'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le groupe'), findsOneWidget);
  });
}
