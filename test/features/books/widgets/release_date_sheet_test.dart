import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/providers/shelf_editor.dart';
import 'package:an_ki/features/books/widgets/release_date_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

final _now = DateTime(2026, 11, 8, 9);

void main() {
  late RecordingBookshelfRepository repository;

  /// Ouvre la feuille depuis un bouton, l'éditeur tenu en vie comme par
  /// l'étagère.
  Future<void> open(WidgetTester tester, {ReleaseDate? current}) async {
    repository = RecordingBookshelfRepository(
      series: [
        const Series(
          id: 's1',
          name: 'One Piece',
          keys: ['one piece'],
          complete: false,
        ),
      ],
    );
    await tester.pumpHarness(
      Consumer(
        builder: (context, ref, _) {
          ref.watch(shelfEditorProvider);
          return TextButton(
            onPressed: () => ReleaseDateSheet.show(
              context,
              seriesId: 's1',
              number: 109,
              current: current,
            ),
            child: const Text('Ouvrir'),
          );
        },
      ),
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repository),
        currentUidProvider.overrideWithValue('fake-uid'),
        clockProvider.overrideWithValue(() => _now),
        todayProvider.overrideWithValue(DateTime(2026, 11, 8)),
      ],
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Enregistrer'),
  );

  Future<void> pickDay(WidgetTester tester, String day) async {
    await tester.tap(find.text('Choisir une date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(day));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('saving waits for a date, then keeps it as the user\'s', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Sortie du tome 109'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    expect(find.text('Effacer la date'), findsNothing);

    await pickDay(tester, '20');
    expect(find.text('20 novembre 2026'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.byType(ReleaseDateSheet), findsNothing);
    expect(
      repository.series.single.next,
      NextVolumeInfo(
        number: 109,
        status: ReleaseStatus.announced,
        date: const ReleaseDate(year: 2026, month: 11, day: 20),
        source: ReleaseSource.user,
        checkedAt: _now,
      ),
    );
  });

  testWidgets('keeps the month only when asked', (tester) async {
    await open(tester);

    await pickDay(tester, '20');
    await tester.tap(find.text('Je ne connais que le mois'));
    await tester.pumpAndSettle();
    expect(find.text('novembre 2026'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(
      repository.series.single.next!.date,
      const ReleaseDate(year: 2026, month: 11),
    );
  });

  testWidgets('a date already entered: prefilled, clearable', (tester) async {
    await open(tester, current: const ReleaseDate(year: 2026, month: 12));

    expect(find.text('décembre 2026'), findsOneWidget);
    // Rien de changé : rien à enregistrer.
    expect(saveButton(tester).onPressed, isNull);

    await tester.tap(find.text('Effacer la date'));
    await tester.pumpAndSettle();

    expect(find.byType(ReleaseDateSheet), findsNothing);
    expect(repository.series.single.next, isNull);
  });

  testWidgets('an entered date older than a year still opens the calendar', (
    tester,
  ) async {
    await open(
      tester,
      current: const ReleaseDate(year: 2025, month: 10, day: 2),
    );

    await tester.tap(find.text('2 octobre 2025'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('meets the tap target and label guidelines', (tester) async {
    await open(tester, current: const ReleaseDate(year: 2026, month: 12));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('holds at 200 % text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await open(tester, current: const ReleaseDate(year: 2026, month: 12));

    expect(tester.takeException(), isNull);
    expect(find.text('Effacer la date'), findsOneWidget);
  });
}
