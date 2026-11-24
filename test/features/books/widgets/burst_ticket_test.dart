import 'package:an_ki/features/books/providers/burst_scan.dart';
import 'package:an_ki/features/books/widgets/burst_ticket.dart';
import 'package:an_ki/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

const _op108 = BurstRow(
  isbn: '9782344059562',
  status: BurstRowStatus.classified,
  seriesId: 'op',
  seriesName: 'One Piece',
  number: 108,
  missingPrevious: [1, 2, 3],
);
const _op109 = BurstRow(
  isbn: '9782723488525',
  status: BurstRowStatus.classified,
  seriesId: 'op',
  seriesName: 'One Piece',
  number: 109,
);
const _lost = BurstRow(isbn: '9782070612758', status: BurstRowStatus.notFound);

void main() {
  final openedSeries = <String>[];
  final openedRows = <BurstRow>[];
  final previous = <BurstRow>[];
  final removed = <List<BurstRow>>[];

  setUp(() {
    openedSeries.clear();
    openedRows.clear();
    previous.clear();
    removed.clear();
  });

  Future<void> pumpTicket(WidgetTester tester, List<BurstRow> rows) =>
      tester.pumpHarness(
        SizedBox(
          height: 500,
          child: BurstTicket(
            rows: rows,
            onOpenSeries: openedSeries.add,
            onOpenRow: openedRows.add,
            onAddPrevious: previous.add,
            onRemove: removed.add,
          ),
        ),
      );

  testWidgets('empty: says where scanned volumes go', (tester) async {
    await pumpTicket(tester, const []);

    expect(find.text('Cette session'), findsOneWidget);
    expect(
      find.text("Les tomes scannés s'ajoutent ici, rangés par série."),
      findsOneWidget,
    );
  });

  testWidgets('groups a series, then lists the loose volumes', (tester) async {
    await pumpTicket(tester, const [_op109, _lost, _op108]);

    expect(find.text('3 tomes ajoutés'), findsOneWidget);
    expect(find.text('One Piece'), findsOneWidget);
    expect(find.text('+2 · tomes 108 et 109'), findsOneWidget);
    expect(find.text('Introuvable · Classer'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('One Piece')).dy,
      lessThan(tester.getTopLeft(find.text('Introuvable · Classer')).dy),
    );
  });

  testWidgets('a group opens its series, a loose volume its correction', (
    tester,
  ) async {
    await pumpTicket(tester, const [_op109, _lost, _op108]);

    await tester.tap(find.text('+2 · tomes 108 et 109'));
    await tester.tap(find.text('Introuvable · Classer'));

    expect(openedSeries, ['op']);
    expect(openedRows, [_lost]);
  });

  testWidgets('removes a group or a loose volume by name', (tester) async {
    await pumpTicket(tester, const [_op109, _lost, _op108]);

    await tester.tap(
      find.byTooltip('Retirer les tomes 108 et 109 de One Piece'),
    );
    await tester.tap(find.byTooltip('Retirer ${_lost.isbn}'));

    expect(removed, [
      [_op109, _op108],
      [_lost],
    ]);
  });

  testWidgets('offers the previous volumes of the lowest one', (tester) async {
    await pumpTicket(tester, const [_op109, _op108]);

    await tester.tap(find.text("J'ai aussi les tomes 1 à 3"));

    expect(previous, [_op108]);
  });

  testWidgets('names what a removal took away', (tester) async {
    final context = await tester.pumpLocalizedContext();
    final l10n = AppLocalizations.of(context);

    expect(
      burstRemovedText(l10n, const [_op109, _op108]),
      'One Piece, tomes 108 et 109 retirés de la collection',
    );
    expect(
      burstRemovedText(l10n, const [_op108]),
      'One Piece, tome 108 retiré de la collection',
    );
    expect(
      burstRemovedText(l10n, const [_lost]),
      '${_lost.isbn} retiré de la collection',
    );
  });

  testWidgets('reads a group as one sentence, large targets', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpTicket(tester, const [_op109, _lost, _op108]);

    expect(
      find.bySemanticsLabel('One Piece, 2 tomes ajoutés : 108 et 109'),
      findsOneWidget,
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
