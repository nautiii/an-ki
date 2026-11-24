import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/widgets/next_volume_card.dart';
import 'package:an_ki/features/books/widgets/release_date_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

final _today = DateTime(2026, 11, 24);

ShelfEntry _entry({NextVolumeInfo? next, bool complete = false}) => shelfOf(
  [
    Series(
      id: 's1',
      name: 'One Piece',
      keys: const ['one piece'],
      complete: complete,
      next: next,
    ),
  ],
  [
    Volume(
      id: 'v1',
      seriesId: 's1',
      number: 1,
      title: 'Tome 1',
      authors: const [],
      lookup: LookupState.found,
      addedAt: DateTime(2026),
    ),
  ],
).entries.single;

NextVolumeInfo _info(
  ReleaseStatus status, {
  ReleaseDate? date,
  ReleaseSource source = ReleaseSource.bnf,
}) => NextVolumeInfo(
  number: 2,
  status: status,
  date: date,
  source: source,
  checkedAt: DateTime(2026, 11, 8),
);

void main() {
  Future<List<int>> pumpCard(WidgetTester tester, ShelfEntry entry) async {
    final bought = <int>[];
    await tester.pumpHarness(
      NextVolumeCard(entry: entry, today: _today, onBought: bought.add),
    );
    return bought;
  }

  testWidgets('an announced volume: the date, how soon, its source', (
    tester,
  ) async {
    await pumpCard(
      tester,
      _entry(
        next: _info(
          ReleaseStatus.announced,
          date: const ReleaseDate(year: 2026, month: 12, day: 3),
        ),
      ),
    );

    expect(find.text('Prochain · tome 2'), findsOneWidget);
    expect(find.text('3 décembre'), findsOneWidget);
    expect(find.text('dans 9 jours'), findsOneWidget);
    expect(find.text('selon la BnF · vérifié le 8 nov.'), findsOneWidget);
    expect(find.text('Ajouter la date'), findsOneWidget);
  });

  testWidgets('a month alone has no countdown, a typed date is edited', (
    tester,
  ) async {
    await pumpCard(
      tester,
      _entry(
        next: _info(
          ReleaseStatus.announced,
          date: const ReleaseDate(year: 2027, month: 1),
          source: ReleaseSource.user,
        ),
      ),
    );

    expect(find.text('janvier 2027'), findsOneWidget);
    expect(find.textContaining('dans'), findsNothing);
    expect(find.text('Modifier la date'), findsOneWidget);

    await tester.tap(find.text('Modifier la date'));
    await tester.pumpAndSettle();
    expect(find.byType(ReleaseDateSheet), findsOneWidget);
  });

  testWidgets('a released volume: « Je l\'ai acheté » marks it', (
    tester,
  ) async {
    final bought = await pumpCard(
      tester,
      _entry(next: _info(ReleaseStatus.released)),
    );

    expect(find.text('Le tome 2 est paru'), findsOneWidget);
    await tester.tap(find.text("Je l'ai acheté"));

    expect(bought, [2]);
  });

  testWidgets('says what the button marks', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCard(tester, _entry(next: _info(ReleaseStatus.released)));

    expect(find.bySemanticsLabel("J'ai acheté le tome 2"), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('a released volume still lets its date be changed', (
    tester,
  ) async {
    await pumpCard(
      tester,
      _entry(
        next: _info(
          ReleaseStatus.announced,
          date: const ReleaseDate(year: 2026, month: 11, day: 3),
          source: ReleaseSource.user,
        ),
      ),
    );

    // Date saisie et dépassée : « paru », mais on peut la corriger.
    expect(find.text('Le tome 2 est paru'), findsOneWidget);
    await tester.tap(find.text('Modifier la date'));
    await tester.pumpAndSettle();

    expect(find.byType(ReleaseDateSheet), findsOneWidget);
  });

  testWidgets('an unknown date offers to add one', (tester) async {
    await pumpCard(tester, _entry());

    expect(find.text('Tome 2 · date inconnue'), findsOneWidget);
    expect(find.text('Ajouter la date'), findsOneWidget);
  });

  testWidgets('a closed series has nothing to wait for', (tester) async {
    await pumpCard(tester, _entry(complete: true));

    expect(find.text('Série terminée : rien à attendre'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });
}
