import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_agenda.dart';
import 'package:an_ki/features/books/widgets/to_buy_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

final _today = DateTime(2026, 11, 24);

ShelfPurchase _purchase(String id, String name, {ReleaseDate? date}) {
  final series = Series(
    id: id,
    name: name,
    keys: [name.toLowerCase()],
    complete: false,
    next: NextVolumeInfo(
      number: 7,
      status: date == null ? ReleaseStatus.released : ReleaseStatus.announced,
      date: date,
      source: ReleaseSource.bnf,
      checkedAt: DateTime(2026, 11),
    ),
  );
  return ShelfPurchase(
    entry: shelfOf([series], const []).entries.single,
    number: 7,
  );
}

void main() {
  final blacksad = _purchase(
    'b',
    'Blacksad',
    date: const ReleaseDate(year: 2026, month: 11, day: 3),
  );
  final spy = _purchase('s', 'Spy x Family');

  Future<(List<ShelfPurchase>, List<ShelfPurchase>)> pumpCard(
    WidgetTester tester, {
    double width = 400,
  }) async {
    final bought = <ShelfPurchase>[];
    final opened = <ShelfPurchase>[];
    await tester.pumpHarness(
      Center(
        child: SizedBox(
          width: width,
          child: ToBuyCard(
            purchases: [blacksad, spy],
            today: _today,
            onBought: bought.add,
            onOpen: opened.add,
          ),
        ),
      ),
    );
    return (bought, opened);
  }

  testWidgets('lists each released volume with when it came out', (
    tester,
  ) async {
    await pumpCard(tester);

    expect(find.text('Paru · pas encore chez vous'), findsOneWidget);
    expect(find.text('Blacksad · tome 7'), findsOneWidget);
    expect(find.text('Paru le 3 novembre'), findsOneWidget);
    expect(find.text('Spy x Family · tome 7'), findsOneWidget);
    expect(find.text('Paru'), findsOneWidget);
  });

  testWidgets('« Acheté » marks that volume, the row opens its series', (
    tester,
  ) async {
    final (bought, opened) = await pumpCard(tester);

    await tester.tap(find.text('Acheté').last);
    await tester.tap(find.text('Blacksad · tome 7'));

    expect(bought, [spy]);
    expect(opened, [blacksad]);
  });

  testWidgets('says what « Acheté » marks, with large targets', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCard(tester);

    expect(
      find.bySemanticsLabel('Marquer Blacksad tome 7 comme acheté'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Blacksad · tome 7, Paru le 3 novembre'),
      findsOneWidget,
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('shows three volumes, then unfolds the others', (tester) async {
    await tester.pumpHarness(
      SingleChildScrollView(
        child: ToBuyCard(
          purchases: [
            for (final name in ['A', 'B', 'C', 'D', 'E']) _purchase(name, name),
          ],
          today: _today,
          onBought: (_) {},
          onOpen: (_) {},
        ),
      ),
    );

    expect(find.text('Acheté'), findsNWidgets(3));
    expect(find.text('E · tome 7'), findsNothing);

    await tester.tap(find.text('Voir les 2 autres tomes'));
    await tester.pump();

    expect(find.text('Acheté'), findsNWidgets(5));
    expect(find.text('E · tome 7'), findsOneWidget);
    expect(find.text('Voir les 2 autres tomes'), findsNothing);
  });

  testWidgets('holds at 200 % text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpHarness(
      SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: ToBuyCard(
            purchases: [blacksad, spy],
            today: _today,
            onBought: (_) {},
            onOpen: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final text = tester.getBottomLeft(find.text('Blacksad · tome 7'));
    expect(
      tester.getTopLeft(find.text('Acheté').first).dy,
      greaterThan(text.dy),
    );
  });

  testWidgets('on a narrow screen, the button goes under the text', (
    tester,
  ) async {
    await pumpCard(tester, width: 280);

    final text = tester.getBottomLeft(find.text('Blacksad · tome 7'));
    final button = tester.getTopLeft(find.text('Acheté').first);
    expect(button.dy, greaterThan(text.dy));
    expect(tester.takeException(), isNull);
  });
}
